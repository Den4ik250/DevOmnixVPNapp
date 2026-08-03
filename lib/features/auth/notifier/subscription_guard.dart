import 'dart:async';

import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Проверка подписки в трёх точках (Авторизация.md).
///
///   1. при запуске приложения;
///   2. при нажатии «Подключиться» — с кешем на 5 минут;
///   3. раз в час, пока VPN активен → отключить, если подписки уже нет.
///
/// Закрывает три случая, в которых доступ обязан прекратиться, а сам по себе
/// не прекращается: возврат звёзд, истечение срока и отключение админом.
/// Без третьей точки человек, оплативший и получивший возврат, оставался бы
/// подключённым до перезапуска приложения.
class SubscriptionGuard extends Notifier<bool> {
  static const _cacheTtl = Duration(minutes: 5);
  static const _pollInterval = Duration(hours: 1);

  DateTime? _checkedAt;
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());

    // Часовой опрос включается вместе с VPN и гаснет вместе с ним: проверять
    // подписку у отключённого клиента незачем, а забытый таймер жёг бы батарею.
    ref.listen(connectionNotifierProvider, (_, next) {
      final connected = next.valueOrNull?.isConnected ?? false;
      if (connected) {
        startPolling();
      } else {
        stopPolling();
      }
    });

    // Стартовое значение — из прошлого запуска, чтобы UI не мигал «нет подписки»
    // до первого ответа бэкенда.
    return ref.read(Preferences.hasActiveSub);
  }

  /// Точка 1: старт приложения.
  Future<bool> checkOnStartup() => _refresh();

  /// Точка 2: перед подключением. Свежий ответ моложе 5 минут переиспользуем —
  /// иначе каждое нажатие кнопки ждало бы сеть.
  Future<bool> ensureActiveBeforeConnect() async {
    final at = _checkedAt;
    if (at != null && DateTime.now().difference(at) < _cacheTtl) {
      return state;
    }
    return _refresh();
  }

  /// Точка 3: пока VPN активен — проверяем раз в час.
  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) async {
      final active = await _refresh();
      if (!active) {
        // Подписки нет — рвём соединение. Молчать нельзя: человек будет думать,
        // что VPN работает, хотя доступ уже отозван.
        await ref.read(connectionNotifierProvider.notifier).abortConnection();
        stopPolling();
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Сбрасывает кеш — после оплаты статус нужен свежий, без ожидания 5 минут.
  void invalidateCache() => _checkedAt = null;

  Future<bool> _refresh() async {
    try {
      final dio = ref.read(backendDioProvider);
      final r = await dio.get('/auth/me');
      final data = Map<String, dynamic>.from(r.data as Map);
      final active = data['has_active_sub'] == true;

      _checkedAt = DateTime.now();
      state = active;
      await ref.read(Preferences.hasActiveSub.notifier).update(active);

      final publicId = data['public_id'];
      if (publicId != null) {
        await ref.read(Preferences.publicId.notifier).update('$publicId');
      }
      return active;
    } catch (_) {
      // Сеть недоступна — НЕ отзываем доступ. Иначе любой обрыв связи
      // отключал бы VPN у честно оплативших, а офлайн у VPN-клиента обычен.
      // Кеш не обновляем: следующая попытка сходит в сеть заново.
      return state;
    }
  }
}

final subscriptionGuardProvider =
    NotifierProvider<SubscriptionGuard, bool>(SubscriptionGuard.new);
