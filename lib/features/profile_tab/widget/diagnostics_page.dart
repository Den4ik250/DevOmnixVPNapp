import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DiagnosticsPage extends HookConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pingAsync = ref.watch(_pingProvider);
    final resetState = ref.watch(_resetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Ping ─────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.network_ping_rounded, color: theme.colorScheme.primary),
                      const Gap(8),
                      Text('Пинг сервера', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(_pingProvider),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                  const Gap(12),
                  pingAsync.when(
                    data: (result) {
                      final reachable = result['reachable'] as bool? ?? false;
                      final latency = result['latency_ms'];
                      final host = result['host'] as String? ?? '';
                      return Row(
                        children: [
                          Icon(
                            reachable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: reachable ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const Gap(8),
                          Text(
                            reachable
                                ? '$host — $latency мс'
                                : '$host — недоступен',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ).animate().fadeIn();
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Нет активной подписки или ошибка соединения',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),
          // ── Reset config ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.autorenew_rounded, color: theme.colorScheme.primary),
                      const Gap(8),
                      Text('Пересоздать конфигурацию', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    'Удалит текущий профиль на сервере и создаст новый VLESS-ключ. '
                    'Используйте если VPN не подключается.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Gap(12),
                  resetState.when(
                    data: (url) => url != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                  Gap(6),
                                  Text('Конфигурация обновлена!'),
                                ],
                              ),
                              const Gap(4),
                              Text(
                                url,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ).animate().fadeIn()
                        : FilledButton.icon(
                            onPressed: () => ref.read(_resetProvider.notifier).reset(),
                            icon: const Icon(Icons.autorenew_rounded),
                            label: const Text('Сбросить и пересоздать'),
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Column(
                      children: [
                        Text('Ошибка: $e', style: TextStyle(color: theme.colorScheme.error)),
                        FilledButton.icon(
                          onPressed: () => ref.read(_resetProvider.notifier).reset(),
                          icon: const Icon(Icons.autorenew_rounded),
                          label: const Text('Попробовать снова'),
                        ),
                      ],
                    ),
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

// ── Providers ─────────────────────────────────────────────────────────────────

final _pingProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(backendDioProvider);
  final r = await dio.get('/vpn/ping');
  return Map<String, dynamic>.from(r.data as Map);
});

class _ResetNotifier extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> reset() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(backendDioProvider);
      final r = await dio.post('/vpn/reset');
      return (r.data as Map<String, dynamic>)['vless_url'] as String?;
    });
  }
}

final _resetProvider = AsyncNotifierProvider.autoDispose<_ResetNotifier, String?>(
  _ResetNotifier.new,
);
