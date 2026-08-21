import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/features/subscription/notifier/active_subscription_provider.dart';
import 'package:devomnix/features/subscription/widget/traffic_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Предупреждение на главной: лимит трафика выбран, VPN больше не работает.
///
/// 🔴 Ставится именно на главной. Подписка при исчерпанном лимите остаётся
/// «активной», кнопка подключения выглядит рабочей — и человек упирается
/// в молчащий туннель, не понимая причины. Ждать, пока он сам дойдёт до
/// «Мой аккаунт», значит оставить его с ощущением сломанного приложения.
class TrafficExceededBanner extends ConsumerWidget {
  const TrafficExceededBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull, а не when: пока статус грузится или сеть молчит, баннера
    // просто нет. Обвинить человека в перерасходе по догадке — хуже, чем
    // промолчать лишнюю секунду.
    final traffic = ref.watch(trafficUsageProvider).valueOrNull;
    if (traffic == null || !traffic.exceeded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: .4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.goNamed('plans'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.data_usage_rounded,
                      color: theme.colorScheme.onErrorContainer,
                      size: 22,
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Трафик закончился',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Обновите тариф, чтобы снова подключаться',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer
                                  .withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ],
                ),
                const Gap(10),
                TrafficBar(traffic: traffic, compact: true),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -.08);
  }
}
