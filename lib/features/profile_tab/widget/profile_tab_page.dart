import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/core/app_info/app_info_provider.dart';
import 'package:devomnix/core/router/go_router/go_router_notifier.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
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
                    error: (_, __) => Text(
                      'Нет активной подписки',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
              loading: () => const Text('Загрузка...'),
              error: (_, __) => const Text('DevOmnix VPN'),
            ),
          ),
        ],
      ),
    );
  }
}

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(backendDioProvider);
  final r = await dio.get('/auth/me');
  return Map<String, dynamic>.from(r.data as Map);
});

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

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.title,
    this.subtitle,
    required this.isActive,
    required this.isAuto,
    required this.onSelect,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isAuto;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

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
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 20),
              tooltip: 'Удалить',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
