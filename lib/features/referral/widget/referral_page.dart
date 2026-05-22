import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _ReferralData {
  const _ReferralData({
    required this.code,
    required this.inviteUrl,
    required this.totalInvited,
    required this.totalBonusEarned,
  });
  final String code;
  final String inviteUrl;
  final int totalInvited;
  final double totalBonusEarned;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _referralProvider = FutureProvider<_ReferralData>((ref) async {
  final dio = ref.watch(backendDioProvider);
  final response = await dio.get('/referral/my');
  final data = response.data as Map<String, dynamic>;
  return _ReferralData(
    code: data['code'] as String,
    inviteUrl: data['invite_url'] as String,
    totalInvited: data['total_invited'] as int,
    totalBonusEarned: (data['total_bonus_earned'] as num).toDouble(),
  );
});

// ── Page ─────────────────────────────────────────────────────────────────────

class ReferralPage extends ConsumerWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refAsync = ref.watch(_referralProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Реферальная программа'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_referralProvider),
          ),
        ],
      ),
      body: refAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const Gap(16),
              Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
              const Gap(8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_referralProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (ref_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatsRow(totalInvited: ref_.totalInvited, bonusEarned: ref_.totalBonusEarned)
                  .animate()
                  .fadeIn(duration: 400.ms),
              const Gap(20),
              _HowItWorksCard().animate().fadeIn(delay: 100.ms).slideY(begin: .05),
              const Gap(20),
              _InviteLinkCard(code: ref_.code, inviteUrl: ref_.inviteUrl)
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: .05),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.totalInvited, required this.bonusEarned});

  final int totalInvited;
  final double bonusEarned;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Приглашено', value: '$totalInvited', icon: Icons.people_alt_outlined)),
        const Gap(12),
        Expanded(
          child: _StatCard(
            label: 'Заработано',
            value: '${bonusEarned.toStringAsFixed(0)} ₽',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const Gap(8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Как это работает', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(16),
            const _HowStep(
              icon: Icons.share,
              title: 'Поделитесь ссылкой',
              body: 'Отправьте вашу реферальную ссылку другу',
            ),
            const Gap(12),
            const _HowStep(
              icon: Icons.person_add,
              title: 'Друг регистрируется',
              body: 'Он открывает бота по вашей ссылке и оформляет подписку',
            ),
            const Gap(12),
            const _HowStep(
              icon: Icons.wallet,
              title: 'Вы получаете бонус',
              body: 'Стандарт: +50 ₽ на кошелёк, друг −30%\nПремиум: +80 ₽ на кошелёк, друг −50%',
            ),
          ],
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.code, required this.inviteUrl});

  final String code;
  final String inviteUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ваша реферальная ссылка', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteUrl,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ссылка скопирована'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Gap(12),
            FilledButton.icon(
              onPressed: () => Share.share('Присоединяйся к DevOmnix VPN!\n$inviteUrl'),
              icon: const Icon(Icons.share),
              label: const Text('Поделиться'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
