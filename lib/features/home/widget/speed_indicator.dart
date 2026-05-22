import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedIndicator extends ConsumerWidget {
  const SpeedIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider).valueOrNull;
    if (connectionStatus == null || connectionStatus is! Connected) {
      return const SizedBox.shrink();
    }

    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    final theme = Theme.of(context);

    final downSpeed = _formatSpeed(stats?.downlink ?? Int64.ZERO);
    final upSpeed = _formatSpeed(stats?.uplink ?? Int64.ZERO);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SpeedColumn(
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF1DB954),
            label: 'Загрузка',
            speed: downSpeed,
          ),
          Container(width: 1, height: 36, color: theme.colorScheme.outlineVariant),
          _SpeedColumn(
            icon: Icons.arrow_upward_rounded,
            color: theme.colorScheme.primary,
            label: 'Отдача',
            speed: upSpeed,
          ),
        ],
      ),
    );
  }

  static String _formatSpeed(Int64 bytesPerSec) {
    final v = bytesPerSec.toInt();
    if (v < 1024) return '$v B/s';
    if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB/s';
    return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
}

class _SpeedColumn extends StatelessWidget {
  const _SpeedColumn({required this.icon, required this.color, required this.label, required this.speed});

  final IconData icon;
  final Color color;
  final String label;
  final String speed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(speed, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
