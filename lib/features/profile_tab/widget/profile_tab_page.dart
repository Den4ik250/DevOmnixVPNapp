import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/backend/backend_api_provider.dart';
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
