import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/notifier/subscription_guard.dart';
import 'package:devomnix/features/auth/widget/bot_link_launcher.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:devomnix/features/subscription/notifier/active_subscription_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

/// Устройство из `GET /devices/`.
class _Device {
  const _Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSeen,
    required this.isCurrent,
  });

  final int id;
  final String? name;
  final String? platform;
  final DateTime? lastSeen;

  /// Проставляет бэкенд, сверяя `device_fingerprint` с `user.device_id`.
  final bool isCurrent;

  factory _Device.fromJson(Map<String, dynamic> json) => _Device(
        id: json['id'] as int,
        name: (json['device_name'] as String?)?.trim(),
        platform: json['platform'] as String?,
        // Сервер отдаёт время в UTC — без toLocal() «последний вход» уезжает
        // на часовой пояс, и человек видит будущее или вчерашний день.
        lastSeen: json['last_seen'] == null
            ? null
            : DateTime.tryParse(json['last_seen'] as String)?.toLocal(),
        isCurrent: json['is_current'] as bool? ?? false,
      );
}

/// Аккаунт и его устройства одним запросом-парой.
///
/// Оба запроса нужны экрану целиком: показывать ID без устройств или наоборот
/// смысла нет, а две отдельные загрузки дали бы два спиннера и два разных
/// сообщения об ошибке на одной странице.
class _Account {
  const _Account({required this.me, required this.devices});

  final Map<String, dynamic> me;
  final List<_Device> devices;

  int? get publicId => me['public_id'] as int?;
  String? get phone => me['phone'] as String?;
  String? get telegramUsername => (me['telegram_username'] as String?)?.trim();
  bool get telegramLinked => me['telegram_id'] != null;

  /// Отображаемое имя. Приезжает из Telegram при привязке, дальше человек
  /// правит его сам — в Telegram имя одно на все сервисы, а здесь это
  /// подпись в его собственном кабинете.
  String? get firstName => (me['first_name'] as String?)?.trim();

  /// Промо за полные данные уже получено.
  bool get promoUsed => me['promo_used'] == true;

  /// Чего не хватает для приветственного промо. Пусто — можно активировать.
  List<String> get missingForPromo => [
        if ((firstName ?? '').isEmpty) 'имя',
        if (!telegramLinked) 'Telegram',
        if ((phone ?? '').isEmpty) 'номер телефона',
      ];
  DateTime? get createdAt {
    final raw = me['created_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

final _accountProvider = FutureProvider.autoDispose<_Account>((ref) async {
  // `/auth/me` берём из общего кеша (см. SubscriptionGuard): экран открывается
  // из Профиля, который только что его запросил, — второй раз ходить незачем.
  ref.watch(Preferences.jwtToken);
  ref.watch(accountRevisionProvider);
  final me = await ref
      .read(subscriptionGuardProvider.notifier)
      .fetchMe(timeout: const Duration(seconds: 12));
  final devices = await ref.read(backendDioProvider).get('/devices/');
  return _Account(
    me: me.me,
    devices: (devices.data as List)
        .map((raw) => _Device.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(),
  );
});

// ── Page ─────────────────────────────────────────────────────────────────────

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(_accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой аккаунт'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
            onPressed: () => ref.invalidate(_accountProvider),
          ),
        ],
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const Gap(16),
                Text('Не удалось загрузить аккаунт', style: theme.textTheme.titleMedium),
                const Gap(8),
                SelectableText(
                  describeBackendError(e),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const Gap(8),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(_accountProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_accountProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _IdentityCard(account: data).animate().fadeIn(duration: 300.ms),
              const Gap(12),
              _SubscriptionCard(account: data)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 30.ms),
              const Gap(12),
              _LinksCard(account: data).animate().fadeIn(duration: 300.ms, delay: 60.ms),
              const Gap(12),
              _DevicesCard(devices: data.devices).animate().fadeIn(duration: 300.ms, delay: 120.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ID ───────────────────────────────────────────────────────────────────────

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.account});

  final _Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final id = account.publicId;
    final createdAt = account.createdAt;
    final name = account.firstName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Имя — первое, что человек видит: оно же стоит в шапке главной.
            Row(
              children: [
                Expanded(
                  child: Text(
                    (name?.isNotEmpty ?? false) ? name! : 'Имя не указано',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (name?.isNotEmpty ?? false)
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Изменить имя',
                  onPressed: () => _editName(context, ref, name),
                ),
              ],
            ),
            const Gap(12),
            Text('Ваш ID', style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            const Gap(4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    id?.toString() ?? '—',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (id != null)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Скопировать',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$id'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID скопирован')),
                      );
                    },
                  ),
              ],
            ),
            Text(
              'Назовите этот номер в поддержке — по нему вас найдут.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (createdAt != null) ...[
              const Gap(8),
              Text(
                'С нами с ${DateFormat('dd.MM.yyyy').format(createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ваше имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 128,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Как к вам обращаться',
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final name = value.trim();
    if (name.isEmpty || name == (current ?? '')) return;

    try {
      await ref.read(backendDioProvider).patch('/auth/name', data: {'first_name': name});
      // Счётчик, а не invalidate конкретного провайдера: имя показывают три
      // экрана сразу, и каждый подписан на эту ревизию.
      ref.read(accountRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя сохранено')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: ${describeBackendError(e)}')),
        );
      }
    }
  }
}

// ── Подписка ─────────────────────────────────────────────────────────────────

/// Тариф, срок и что с ним можно сделать.
///
/// 🔴 Данные берутся из `GET /subscriptions/active`, а не из `/auth/me`:
/// там только булево `has_active_sub`, и экран мог сказать лишь «активна».
/// Человек не знал ни тарифа, ни даты — а с пробным днём это означало, что
/// доступ пропадал завтра без предупреждения.
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.account});

  final _Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sub = ref.watch(activeSubscriptionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Подписка', style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            const Gap(6),
            sub.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              // Отказ сети — не «подписки нет». Пока эти два случая писались
              // одинаково, обрыв связи выглядел как отобранный доступ.
              error: (e, _) => Text(
                'Статус неизвестен: ${describeBackendError(e)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
              data: (data) => _body(context, theme, data),
            ),
            ..._promoBlock(context, ref, theme),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme, ActiveSubscription? data) {
    if (data == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Нет активной подписки', style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.error)),
          const Gap(12),
          FilledButton.tonal(
            onPressed: () => context.goNamed('plans'),
            child: const Text('Выбрать тариф'),
          ),
        ],
      );
    }

    final remaining = data.remainingLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.planName,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(2),
        Text(
          data.isPermanent
              ? 'Действует бессрочно'
              : data.expiresAt == null
                  ? 'Срок не указан'
                  : 'До ${DateFormat('dd.MM.yyyy, HH:mm').format(data.expiresAt!.toLocal())}'
                      '${remaining == null ? '' : ' · $remaining'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (data.isDeviceTrial) ...[
          const Gap(6),
          Text(
            'Это пробный день нового пользователя — он выдан автоматически '
            'и не продлевается.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Gap(12),
        FilledButton.tonal(
          onPressed: () => context.goNamed('plans'),
          // Бесплатный доступ не продлевают деньгами — предлагаем выбрать тариф.
          child: Text(data.isFree ? 'Выбрать тариф' : 'Продлить подписку'),
        ),
      ],
    );
  }

  /// Приветственное промо: 3 дня безлимита за имя + Telegram + телефон.
  List<Widget> _promoBlock(BuildContext context, WidgetRef ref, ThemeData theme) {
    if (account.promoUsed) return const [];
    final missing = account.missingForPromo;

    return [
      const Divider(height: 24),
      Text('3 дня безлимита', style: theme.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600)),
      const Gap(4),
      Text(
        missing.isEmpty
            ? 'Данные заполнены — промо можно получить.'
            : 'Чтобы получить, укажите: ${missing.join(', ')}.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const Gap(8),
      FilledButton(
        // Кнопка не прячется при неполных данных, а гаснет: спрятанную
        // человек не найдёт и не узнает, что промо вообще существует.
        onPressed: missing.isEmpty ? () => _activatePromo(context, ref) : null,
        child: const Text('Получить промо'),
      ),
    ];
  }

  Future<void> _activatePromo(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backendDioProvider).post('/promo/welcome');
      ref.read(accountRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Промо активировано: 3 дня безлимита')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeBackendError(e))),
        );
      }
    }
  }
}

// ── Telegram и телефон ───────────────────────────────────────────────────────

class _LinksCard extends ConsumerWidget {
  const _LinksCard({required this.account});

  final _Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linked = account.telegramLinked;
    final username = account.telegramUsername;
    final phone = account.phone;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.telegram, color: theme.colorScheme.primary),
            title: const Text('Telegram'),
            subtitle: Text(
              linked
                  ? (username == null || username.isEmpty ? 'Привязан' : '@$username')
                  : 'Не привязан',
              style: TextStyle(
                color: linked ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
              ),
            ),
            trailing: linked
                ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600)
                : FilledButton.tonal(
                    onPressed: () => openBotWithLink(context, ref),
                    child: const Text('Привязать'),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.phone_rounded, color: theme.colorScheme.primary),
            title: const Text('Телефон'),
            subtitle: Text(
              phone == null || phone.isEmpty ? 'Не указан' : phone,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (!linked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Привязка объединяет аккаунт приложения и Telegram: подписка, '
                'кошелёк и история становятся общими.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Устройства ───────────────────────────────────────────────────────────────

class _DevicesCard extends ConsumerStatefulWidget {
  const _DevicesCard({required this.devices});

  final List<_Device> devices;

  @override
  ConsumerState<_DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends ConsumerState<_DevicesCard> {
  /// id устройства, которое сейчас отключается — чтобы не жать кнопку дважды.
  int? _kicking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = widget.devices;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.devices_rounded, color: theme.colorScheme.primary),
                const Gap(8),
                Text('Устройства', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${devices.length}', style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Пока пусто. Устройство появится здесь после следующего запуска приложения.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final device in devices) ...[
              const Divider(height: 1),
              _DeviceTile(
                device: device,
                busy: _kicking == device.id,
                onKick: device.isCurrent ? null : () => _kick(device),
              ),
            ],
        ],
      ),
    );
  }

  Future<void> _kick(_Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отключить устройство?'),
        content: Text(
          '«${_deviceTitle(device)}» потеряет доступ к VPN. '
          'Владелец сможет войти заново.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отключить')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _kicking = device.id);
    try {
      await ref.read(backendDioProvider).post('/devices/kick/${device.id}');
      ref.invalidate(_accountProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeBackendError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _kicking = null);
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.busy, this.onKick});

  final _Device device;
  final bool busy;

  /// `null` для текущего устройства — отключать себя бессмысленно.
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(_platformIcon(device.platform), color: theme.colorScheme.primary),
      title: Row(
        children: [
          Flexible(child: Text(_deviceTitle(device), overflow: TextOverflow.ellipsis)),
          if (device.isCurrent) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'это устройство',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(_lastSeenLabel(device.lastSeen)),
      trailing: onKick == null
          ? null
          : busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Отключить',
                  onPressed: onKick,
                ),
    );
  }
}

String _deviceTitle(_Device device) {
  final name = device.name;
  if (name != null && name.isNotEmpty) return name;
  // Старые записи и клиенты до v1.3.6 модель не присылали.
  return 'Неизвестное устройство';
}

IconData _platformIcon(String? platform) => switch (platform) {
      'android' => Icons.android_rounded,
      'ios' || 'macos' => Icons.phone_iphone_rounded,
      'windows' => Icons.desktop_windows_rounded,
      'linux' => Icons.computer_rounded,
      _ => Icons.device_unknown_rounded,
    };

String _lastSeenLabel(DateTime? lastSeen) {
  if (lastSeen == null) return 'Последний вход неизвестен';
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return 'Сейчас в сети';
  if (diff.inHours < 1) return 'Был ${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return 'Был ${diff.inHours} ч назад';
  if (diff.inDays < 7) return 'Был ${diff.inDays} дн назад';
  return 'Был ${DateFormat('dd.MM.yyyy').format(lastSeen)}';
}
