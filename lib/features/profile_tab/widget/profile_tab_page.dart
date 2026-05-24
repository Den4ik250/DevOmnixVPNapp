import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/backend/backend_api_provider.dart';
import 'package:hiddify/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
            textCapitalization: TextCapitalization.characters,
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
    final code = widget.controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Введите промокод');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(backendDioProvider);
      final resp = await dio.post('/promo/activate', data: {'code': code});
      final data = resp.data as Map<String, dynamic>;

      // Auto-add / update VPN profile so user can connect immediately
      bool profileAdded = false;
      try {
        await ref.read(vpnAutoInitProvider.notifier).switchServer(1);
        profileAdded = true;
      } catch (_) {}

      if (!context.mounted) return;
      Navigator.pop(context);
      await _showSuccess(context, data, profileAdded: profileAdded);
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

Future<void> _showSuccess(BuildContext context, Map<String, dynamic> data, {bool profileAdded = false}) async {
  final vless = data['vless_url'] as String? ?? '';
  final expires = data['expires_at'] as String?;
  String expiryText = '';
  if (expires != null) {
    try {
      final dt = DateTime.parse(expires).toLocal();
      expiryText = 'до ${dt.day}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
    } catch (_) {}
  }

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
        const Gap(8),
        const Text('Подписка активирована'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expiryText.isNotEmpty) ...[
            Text('Активна $expiryText', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Gap(12),
          ],
          if (profileAdded) ...[
            Row(children: [
              Icon(Icons.wifi_rounded, color: Colors.green.shade600, size: 18),
              const Gap(6),
              const Expanded(child: Text('VPN профиль настроен. Перейдите на главный экран и нажмите «Подключиться».')),
            ]),
          ] else ...[
            const Text('VLESS URL для подключения:'),
            const Gap(8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      vless,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Скопировать',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: vless));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Gap(8),
            const Text(
              'Скопируйте и вставьте в поле добавления профиля (значок + на главном экране).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
      ],
    ),
  );
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final theme = Theme.of(context);
    final meAsync = ref.watch(_meProvider);

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
                  Text(
                    me['has_active_sub'] == true ? 'Подписка активна' : 'Нет активной подписки',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: me['has_active_sub'] == true ? Colors.green : theme.colorScheme.error,
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
