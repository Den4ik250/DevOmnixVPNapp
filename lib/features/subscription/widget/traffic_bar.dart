import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/subscription/model/traffic_usage.dart';

/// Полоса расхода трафика и подпись «Использовано: 1.18 ГБ / 1.00 ГБ».
///
/// Отдельным виджетом, а не куском карточки подписки: тот же блок нужен
/// и на главной в баннере, и дублировать разметку с формулой цвета —
/// значит однажды покрасить полосу красным в одном месте и забыть в другом.
class TrafficBar extends StatelessWidget {
  const TrafficBar({super.key, required this.traffic, this.compact = false});

  final TrafficUsage traffic;

  /// Для баннера: без подписи-остатка, полоса тоньше.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = traffic.ratio;
    final color = _barColor(theme, traffic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            // На безлимите заполняем полосу целиком: пустая полоса читается
            // как «ничего не потрачено», а не как «границы нет».
            value: ratio ?? 1,
            minHeight: compact ? 5 : 7,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const Gap(6),
        Row(
          children: [
            Expanded(
              child: Text(
                traffic.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: traffic.exceeded
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: traffic.exceeded ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (!compact && !traffic.isUnlimited && !traffic.exceeded)
              Text(
                'осталось ${formatTrafficBytes(traffic.remaining)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Красный бейдж «Трафик исчерпан» — тем же способом, что и остальные
/// плашки на странице (устройство, версия): контейнер со скруглением.
class TrafficExceededBadge extends StatelessWidget {
  const TrafficExceededBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.data_usage_rounded,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const Gap(6),
          Text(
            'Трафик исчерпан',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Зелёный → жёлтый → красный. Порог 90% предупреждает заранее: узнать
/// о лимите в момент, когда он уже кончился, — значит узнать поздно.
Color _barColor(ThemeData theme, TrafficUsage traffic) {
  if (traffic.exceeded) return theme.colorScheme.error;
  final ratio = traffic.ratio;
  if (ratio == null) return theme.colorScheme.primary;
  if (ratio >= 0.9) return theme.colorScheme.error;
  if (ratio >= 0.75) return Colors.orange.shade600;
  return theme.colorScheme.primary;
}
