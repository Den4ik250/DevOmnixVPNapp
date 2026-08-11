import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Точечные show: drift экспортирует свой Column, он конфликтует с Flutter.
import 'package:drift/drift.dart' show Value;
import 'package:devomnix/core/db/db.dart' show ProfileEntriesCompanion;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/core/app_info/app_info_provider.dart';
import 'package:devomnix/features/auth/notifier/subscription_guard.dart';
import 'package:devomnix/features/auth/widget/bot_link_launcher.dart';
import 'package:devomnix/core/router/go_router/go_router_notifier.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:devomnix/features/backend_update/model/backend_update_state.dart';
import 'package:devomnix/features/backend_update/notifier/backend_update_notifier.dart';
import 'package:devomnix/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:devomnix/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:devomnix/features/profile/data/profile_data_mapper.dart';
import 'package:devomnix/features/profile/data/profile_data_providers.dart';
import 'package:devomnix/features/profile/model/profile_entity.dart';
import 'package:devomnix/features/profile/model/profile_sort_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileTabPage extends ConsumerWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _AccountHeader(ref: ref),
          const Divider(height: 1),
          const _ServersSection(),
          const Divider(height: 1),
          _ProfileSection(
            icon: Icons.badge_rounded,
            title: 'Мой аккаунт',
            subtitle: 'ID, привязка Telegram и устройства',
            onTap: () => context.goNamed('account'),
          ),
          _ProfileSection(
            icon: Icons.credit_card_rounded,
            title: 'Тарифы и подписка',
            subtitle: 'Купить или продлить подписку',
            onTap: () => context.goNamed('plans'),
          ),
          _ProfileSection(
            icon: Icons.confirmation_num_rounded,
            title: 'Активировать промокод',
            subtitle: 'Введите код для получения подписки',
            onTap: () => _showPromoDialog(context, ref),
          ),
          _ProfileSection(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Кошелёк',
            subtitle: 'Баланс и история транзакций',
            onTap: () => context.goNamed('wallet'),
          ),
          _ProfileSection(
            icon: Icons.people_rounded,
            title: 'Реферальная программа',
            subtitle: 'Пригласите друга — получите бонус',
            onTap: () => context.goNamed('referral'),
          ),
          _ProfileSection(
            icon: Icons.help_outline_rounded,
            title: 'Частые вопросы (FAQ)',
            subtitle: 'Ответы на популярные вопросы',
            onTap: () => context.goNamed('faq'),
          ),
          _ProfileSection(
            icon: Icons.network_check_rounded,
            title: 'Диагностика',
            subtitle: 'Пинг сервера и пересоздание конфига',
            onTap: () => context.goNamed('diagnostics'),
          ),
          // Между «Диагностикой» и «Версией приложения» — по Задачам VPN-Сервиса
          _ProfileSection(
            icon: Icons.telegram,
            title: 'Перейти в ТГ-бот',
            subtitle: 'Привязать аккаунт, оплата и поддержка',
            onTap: () => openBotWithLink(context, ref),
          ),
          const _AppVersionTile(),
        ],
      ),
    );
  }
}

Future<void> _showPromoDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => _PromoDialog(controller: controller, ref: ref),
  );
  controller.dispose();
}

// ── Promo dialog ──────────────────────────────────────────────────────────────

class _PromoDialog extends ConsumerStatefulWidget {
  const _PromoDialog({required this.controller, required this.ref});
  final TextEditingController controller;
  final WidgetRef ref;

  @override
  ConsumerState<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends ConsumerState<_PromoDialog> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Промокод'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Введите промокод для активации подписки:'),
          const Gap(12),
          TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'НАПРИМЕР: PROMO2024',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => widget.controller.clear(),
              ),
            ),
            onSubmitted: (_) => _activate(context),
          ),
          if (_error != null) ...[
            const Gap(8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : () => _activate(context),
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Активировать'),
        ),
      ],
    );
  }

  Future<void> _activate(BuildContext context) async {
    final code = widget.controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите промокод');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(backendDioProvider);
      await dio.post('/promo/activate', data: {'code': code});

      // 🔴 Кеш статуса живёт 5 минут. Без сброса только что активированный
      // промокод не виден нигде: и кнопка, и Профиль ещё пять минут
      // отвечают «нет активной подписки».
      ref.read(subscriptionGuardProvider.notifier).invalidateCache();

      if (!context.mounted) return;
      Navigator.pop(context);
      // Navigate to home tab and trigger automatic VPN connection
      rootNavKey.currentContext?.goNamed('home');
      ref.read(vpnAutoInitProvider.notifier).activateAndConnect();
    } catch (e) {
      String msg = 'Ошибка соединения с сервером';
      try {
        final detail = (e as dynamic).response?.data?['detail'];
        if (detail != null) msg = detail.toString();
      } catch (_) {}
      setState(() { _loading = false; _error = msg; });
    }
  }
}


class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final theme = Theme.of(context);
    final meAsync = ref.watch(_meProvider);

    // Используем централизованный subscriptionStatusProvider
    final subStatus = ref.watch(subscriptionStatusProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, size: 28, color: theme.colorScheme.onPrimaryContainer),
          ),
          const Gap(16),
          Expanded(
            child: meAsync.when(
              data: (me) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me['phone'] != null ? (me['phone'] as String) : 'DevOmnix VPN',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  // Публичный ID — его человек называет в поддержке, по нему
                  // же оператор находит клиента в 3X-UI. Копируется тапом,
                  // чтобы не переписывать десять цифр вручную.
                  if (me['public_id'] != null) ...[
                    const Gap(2),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: '${me['public_id']}'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID скопирован')),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${me['public_id']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Gap(4),
                          Icon(Icons.copy_rounded,
                              size: 12, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ],
                  const Gap(2),
                  // Статус берём из единого provider
                  subStatus.when(
                    data: (isActive) => Text(
                      isActive ? 'Подписка активна' : 'Нет активной подписки',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive ? Colors.green : theme.colorScheme.error,
                      ),
                    ),
                    loading: () => Text('...', style: theme.textTheme.bodySmall),
                    // 🔴 Отказ сети — это не «нет подписки». Пока здесь стояла
                    // та же фраза, обрыв связи выглядел как отобранная
                    // подписка, и человек с активным VIP видел ровно то же,
                    // что человек без оплаты.
                    error: (e, __) => Text(
                      'Статус неизвестен: ${describeBackendError(e)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
              loading: () => const Text('Загрузка...'),
              error: (e, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DevOmnix VPN'),
                  const Gap(2),
                  Text(
                    describeBackendError(e),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () =>
                        ref.read(subscriptionGuardProvider.notifier).invalidateCache(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// `/auth/me` для шапки берём из общего провайдера: раньше здесь был свой
// запрос, и открытие Профиля отправляло два одинаковых `/auth/me` подряд —
// этот и тот, что стоит за статусом подписки.
final _meProvider = accountInfoProvider;

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}

class _AppVersionTile extends ConsumerWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final updateState = ref.watch(backendUpdateProvider);
    final currentVersion = ref.watch(appInfoProvider).valueOrNull?.version ?? '';
    final hasSoftUpdate = updateState.status == BackendUpdateStatus.softUpdate;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
      ),
      title: Row(
        children: [
          Text(
            'Версия приложения',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (hasSoftUpdate) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '!',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        hasSoftUpdate
            ? '$currentVersion → ${updateState.latestVersion}'
            : currentVersion,
        style: theme.textTheme.bodySmall,
      ),
      trailing: hasSoftUpdate ? const Icon(Icons.chevron_right_rounded) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: hasSoftUpdate ? () => _showSoftUpdateDialog(context, updateState) : null,
    );
  }
}

void _showSoftUpdateDialog(BuildContext context, BackendUpdateState state) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Доступна версия ${state.latestVersion}'),
      content: Text(
        state.whatsNew.isNotEmpty
            ? state.whatsNew
            : 'Новая версия приложения доступна для обновления.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () => launchUrl(
            Uri.parse(state.downloadUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Обновить'),
        ),
      ],
    ),
  );
}

// ── Серверы ─────────────────────────────────────────────────────────────────

/// Список всех профилей (авто + ручные), обновляется при изменениях в БД.
final allProfilesProvider = StreamProvider.autoDispose<List<ProfileEntity>>((ref) {
  final ds = ref.watch(profileDataSourceProvider);
  return ds
      .watchAll(sort: ProfilesSort.lastUpdate, sortMode: SortMode.ascending)
      .map((rows) => rows.map((e) => e.toEntity()).toList());
});

class _ServersSection extends ConsumerWidget {
  const _ServersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(allProfilesProvider).valueOrNull ?? const <ProfileEntity>[];

    final autoList = profiles.where((p) => p.name == kAutoProfileName).toList();
    final autoProfile = autoList.isEmpty ? null : autoList.first;
    final manualProfiles = profiles.where((p) => p.name != kAutoProfileName).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Text(
            'Серверы',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ),

        // Автоматический (наш платный) — удалить нельзя
        _ServerTile(
          title: 'Автоматический (наш сервер)',
          subtitle: autoProfile != null
              ? 'Основной платный сервер'
              : 'Оформите подписку, чтобы получить сервер',
          isActive: autoProfile?.active ?? false,
          isAuto: true,
          onSelect: () async {
            if (autoProfile != null) {
              await _select(ref, autoProfile);
            } else {
              await ref.read(vpnAutoInitProvider.notifier).refresh();
            }
          },
        ),

        // Мои серверы (ручные)
        if (manualProfiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(
              'Мои серверы',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ...manualProfiles.map(
          (p) => _ServerTile(
            title: p.name,
            isActive: p.active,
            isAuto: false,
            onSelect: () => _select(ref, p),
            onDelete: () => _confirmDelete(context, ref, p),
            onRename: () => _rename(context, ref, p),
            onEditUrl: () => _editUrl(context, ref, p),
          ),
        ),

        // Добавить свой сервер
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () =>
                ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Добавить свой сервер'),
          ),
        ),
      ],
    );
  }

  Future<void> _select(WidgetRef ref, ProfileEntity profile) async {
    if (profile.active) return;
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.setAsActive(profile.id).run();
    // Переподключение при активном VPN делает ConnectionNotifier
    // (слушатель activeProfileProvider → reconnect), вручную не нужно.
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, ProfileEntity profile) async {
    final name = await _promptText(
      context,
      title: 'Переименовать сервер',
      label: 'Название',
      initial: profile.name,
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == profile.name) return;
    await ref
        .read(profileDataSourceProvider)
        .edit(profile.id, ProfileEntriesCompanion(name: Value(trimmed)));
  }

  /// Правка ссылки сервера. Поле открывается с текущей ссылкой, а не пустым:
  /// ошибка обычно в одном символе, и вслепую её не найти.
  ///
  /// Профили бывают двух видов, и правятся по-разному. `vless://` не проходит
  /// `LinkParser` (тот знает только http(s)/ftp и схемы вида `devomnix://`),
  /// поэтому свои серверы почти всегда **local**: ссылка лежит в
  /// `userOverride.sourceLink`, а в файле — сконвертированный sing-box JSON.
  Future<void> _editUrl(BuildContext context, WidgetRef ref, ProfileEntity profile) async {
    final current = switch (profile) {
      RemoteProfileEntity(:final url) => url,
      LocalProfileEntity() => profile.userOverride?.sourceLink,
    };

    final input = await _promptText(
      context,
      title: 'Редактировать сервер',
      label: 'Ссылка сервера',
      initial: current ?? '',
      maxLines: 6,
      // У профилей, заведённых до появления sourceLink, показывать нечего.
      helperText: current == null ? 'Прежняя ссылка не сохранена — вставьте новую целиком' : null,
    );
    final trimmed = input?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current) return;

    final repo = await ref.read(profileRepositoryProvider.future);

    if (profile is! RemoteProfileEntity) {
      // Local: содержимое переразбирается на месте, id сохраняется. Запись в БД
      // происходит только после успешной валидации, поэтому битая ссылка
      // оставит сервер нетронутым.
      final override = (profile.userOverride ?? const UserOverride()).copyWith(sourceLink: trimmed);
      final result = await repo.offlineUpdate(profile.copyWith(userOverride: override), trimmed).run();
      if (result.isLeft() && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка не подошла — сервер не изменён')),
        );
      }
      return;
    }

    // Remote: `upsertRemote` ищет профиль по URL, а URL изменился — значит
    // будет создан новый, а не обновлён старый. Поэтому сначала добавляем:
    // если ссылка не прошла разбор, старый сервер остаётся на месте.
    final result = await repo.upsertRemote(trimmed).run();
    if (result.isLeft()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка не подошла — сервер не изменён')),
        );
      }
      return;
    }

    final ds = ref.read(profileDataSourceProvider);
    final added = await ds.getByUrl(trimmed);
    if (added == null) return;

    // Имя, которое человек задал сам, важнее remark'а из новой ссылки.
    await ds.edit(added.id, ProfileEntriesCompanion(name: Value(profile.name)));

    if (profile.active) {
      await repo.setAsActive(added.id).run();
    }
    // Активность уже переехала на новый профиль, поэтому isActive: false —
    // иначе DAO активировал бы произвольный профиль из списка.
    await repo.deleteById(profile.id, false).run();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ProfileEntity profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сервер?'),
        content: Text('«${profile.name}» будет удалён из списка.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(profileRepositoryProvider.future);

    if (profile.active) {
      // Удаляем активный ручной профиль. DAO активировал бы profiles.first
      // (произвольный) — вместо этого переключаемся на авто-профиль ДО удаления
      // (один reconnect, без мигания). Если авто нет — fallback на логику DAO.
      final ds = ref.read(profileDataSourceProvider);
      final auto = await ds.getByName(kAutoProfileName);
      if (auto != null) {
        await repo.setAsActive(auto.toEntity().id).run();
        await repo.deleteById(profile.id, false).run();
        return;
      }
    }
    await repo.deleteById(profile.id, profile.active).run();
  }
}

/// Диалог с одним текстовым полем. Поле всегда открывается заполненным —
/// правка вслепую (пустое поле вместо текущего значения) для ссылок неприменима.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  int maxLines = 1,
  String? helperText,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, helperText: helperText, helperMaxLines: 2),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

enum _ServerAction { rename, edit, delete }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const Gap(12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.title,
    this.subtitle,
    required this.isActive,
    required this.isAuto,
    required this.onSelect,
    this.onDelete,
    this.onRename,
    this.onEditUrl,
  });

  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isAuto;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onEditUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onSelect,
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      leading: Icon(
        isAuto ? Icons.cloud_done_rounded : Icons.dns_rounded,
        color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: isActive ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          if (isAuto) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'авто',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
          else
            TextButton(onPressed: onSelect, child: const Text('Выбрать')),
          if (onDelete != null || onRename != null || onEditUrl != null)
            PopupMenuButton<_ServerAction>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'Ещё',
              onSelected: (action) {
                switch (action) {
                  case _ServerAction.rename:
                    onRename?.call();
                  case _ServerAction.edit:
                    onEditUrl?.call();
                  case _ServerAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (_) => [
                if (onRename != null)
                  const PopupMenuItem(
                    value: _ServerAction.rename,
                    child: _MenuRow(icon: Icons.drive_file_rename_outline_rounded, label: 'Переименовать'),
                  ),
                if (onEditUrl != null)
                  const PopupMenuItem(
                    value: _ServerAction.edit,
                    child: _MenuRow(icon: Icons.edit_outlined, label: 'Редактировать'),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _ServerAction.delete,
                    child: _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Удалить',
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
