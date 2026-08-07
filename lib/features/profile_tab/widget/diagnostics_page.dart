import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:dio/dio.dart';
import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:devomnix/features/home/notifier/vpn_auto_init_notifier.dart';
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
                    error: (e, _) => SelectableText(
                      describeBackendError(e),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),
          // ── Connectivity probe ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lan_rounded, color: theme.colorScheme.primary),
                      const Gap(8),
                      Text('Проверка соединения', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(_probeProvider),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    'Три независимые попытки достучаться до бэкенда напрямую, '
                    'мимо остальных экранов. Покажите результат разработчику.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Gap(12),
                  ref.watch(_probeProvider).when(
                        data: (lines) => SelectableText(
                          lines.join('\n'),
                          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => SelectableText(
                          '$e',
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

/// Пошаговая проверка канала до бэкенда.
///
/// Экраны показывают только результат, поэтому обрыв TCP, 401 и ошибку разбора
/// JSON снаружи не отличить. Здесь каждый слой проверяется отдельно и никогда
/// не бросает — любой сбой становится строкой отчёта.
final _probeProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final lines = <String>['Базовый URL: ${Constants.backendBaseUrl}'];
  final uri = Uri.parse(Constants.backendBaseUrl);

  // 1. Голый TCP: отделяет сетевую блокировку от всего, что выше.
  final started = DateTime.now();
  try {
    final socket = await Socket.connect(
      uri.host,
      uri.port,
      timeout: const Duration(seconds: 10),
    );
    final ms = DateTime.now().difference(started).inMilliseconds;
    lines.add('1. TCP ${uri.host}:${uri.port} — соединение есть ($ms мс)');
    socket.destroy();
  } catch (e) {
    lines.add('1. TCP ${uri.host}:${uri.port} — ОТКАЗ: $e');
  }

  // 2. Публичный эндпоинт: без токена, без БД. Работает — значит канал цел.
  try {
    final plain = Dio(BaseOptions(
      baseUrl: Constants.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final r = await plain.get('/subscriptions/plans');
    final count = r.data is List ? (r.data as List).length : -1;
    lines.add('2. GET /subscriptions/plans — ${r.statusCode}, тарифов: $count');
  } catch (e) {
    lines.add('2. GET /subscriptions/plans — ${describeBackendError(e)}');
  }

  // 3. Токен устройства: пустой JWT объясняет и 401, и пустой ID в профиле.
  final jwt = ref.read(Preferences.jwtToken);
  lines.add(jwt.isEmpty
      ? '3. JWT — ПУСТО (вход по device_id не прошёл)'
      : '3. JWT — есть (${jwt.length} симв.)');
  try {
    final r = await ref.read(backendDioProvider).get('/auth/me');
    lines.add('4. GET /auth/me — ${r.statusCode}, public_id: ${r.data is Map ? r.data['public_id'] : '?'}');
  } catch (e) {
    lines.add('4. GET /auth/me — ${describeBackendError(e)}');
  }

  return lines;
});

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
      // Пересоздаёт конфиг на бэкенде, заменяет ТОЛЬКО авто-профиль,
      // делает его активным и переподключается (если VPN включён).
      return await ref.read(vpnAutoInitProvider.notifier).resetAndReconnect();
    });
  }
}

final _resetProvider = AsyncNotifierProvider.autoDispose<_ResetNotifier, String?>(
  _ResetNotifier.new,
);
