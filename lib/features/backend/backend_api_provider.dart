import 'dart:async';

import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/data/auth_repository.dart';
import 'package:devomnix/features/auth/data/device_id_service.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Помечает запрос, который уже переживал восстановление сессии.
/// Без метки 401 на повторе увёл бы в бесконечный цикл перелогинов.
const _retriedKey = 'devomnix_retried_after_401';

/// 🔴 Таймауты короткие намеренно.
///
/// Раньше стояло 15 + 15 секунд, и это ощущалось как «кнопка не нажимается»:
/// нажатие уходило в проверку подписки, та молча ждала полминуты, и только
/// потом экран оживал. Пользователь за это время успевал нажать ещё дважды.
/// Столько ждать незачем: живой сервер отвечает за десятки миллисекунд, а если
/// TCP не встал за 7 секунд — он не встанет и за 15, там фильтр по пути.
const kBackendConnectTimeout = Duration(seconds: 7);
const kBackendReceiveTimeout = Duration(seconds: 10);

/// Dio к бэкенду. Один экземпляр на всё приложение.
///
/// 🔴 Здесь НЕТ `ref.watch(Preferences.jwtToken)`, и это принципиально.
/// Пока он был, провайдер пересоздавался на каждую запись токена — то есть
/// при каждом запуске и при каждом самовосстановлении сессии. Вместе с ним
/// инвалидировались все зависимые провайдеры (`/auth/me`, тарифы, кошелёк,
/// устройства): запросы, ушедшие с прошлым Dio, дописывались в осиротевший
/// `Ref`, экраны перезапускали загрузку с нуля, и «Профиль» мог остаться
/// в спиннере навсегда. Токен читается на каждом запросе в `onRequest`,
/// пересоздавать ради него клиент не нужно.
final backendDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Constants.backendBaseUrl,
    connectTimeout: kBackendConnectTimeout,
    receiveTimeout: kBackendReceiveTimeout,
    sendTimeout: kBackendReceiveTimeout,
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(Preferences.jwtToken);
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 🔴 Самовосстановление сессии.
        //
        // Одна неудачная попытка входа при старте раньше оставляла приложение
        // без JWT до переустановки: дальше КАЖДЫЙ экран получал 401 — тарифы,
        // кошелёк, реферальная программа, пинг. Внешне это неотличимо от
        // «нет связи с сервером».
        //
        // Теперь 401 чинит себя сам: вход по device_id (он переживает
        // переустановку, так что аккаунт тот же) и один повтор запроса.
        // Вход общий на все параллельные запросы — см. [BackendSession].
        final isAuthError = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra[_retriedKey] == true;
        if (!isAuthError || alreadyRetried) {
          return handler.next(error);
        }

        final result = await ref.read(backendSessionProvider).login();
        final token = result?.jwt;
        if (token == null || token.isEmpty) {
          return handler.next(error);
        }

        final options = error.requestOptions
          ..extra[_retriedKey] = true
          ..headers['Authorization'] = 'Bearer $token';
        try {
          final response = await dio.fetch<dynamic>(options);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    ),
  );

  return dio;
});

/// Единственное место, которое логинится по `device_id`.
///
/// 🔴 Раньше вход умели запускать трое сразу: `AuthNotifier.init()` при старте,
/// `backendDioProvider` при пустом токене и обработчик 401. На холодном старте
/// они уходили в сеть одновременно, писали JWT друг поверх друга и множили
/// нагрузку на канал, который и так еле отвечал. Здесь вход один: параллельные
/// вызовы получают одну и ту же попытку.
class BackendSession {
  BackendSession(this._ref);

  final Ref _ref;

  Future<AuthResult?>? _inFlight;

  /// Причина последнего неудачного входа — её показывает Диагностика.
  Object? lastError;

  /// Есть ли сейчас живой токен. Без него запрос уйдёт без `Authorization`
  /// и вернётся 401 — дешевле сначала войти.
  bool get hasToken => _ref.read(Preferences.jwtToken).isNotEmpty;

  /// Возвращает токен, входя при необходимости. Существующий не трогает.
  ///
  /// Одна попытка, без повторов: за этим вызовом стоит открытый экран, и
  /// растягивать его спиннер на три захода нельзя. Повторы — дело стартового
  /// [login], он идёт фоном и подтянет сессию сам.
  Future<String> ensureToken() async {
    final existing = _ref.read(Preferences.jwtToken);
    if (existing.isNotEmpty) return existing;
    final result = await login(attempts: 1);
    return result?.jwt ?? '';
  }

  /// Вход по `device_id`. Никогда не бросает — возвращает null при отказе.
  ///
  /// [attempts] > 1 нужен на старте: первый запрос уходит в момент, когда
  /// Wi-Fi ещё поднимается, и единственная попытка проваливалась на ровном
  /// месте, оставляя приложение без сессии до перезапуска.
  Future<AuthResult?> login({int attempts = 3}) {
    final running = _inFlight;
    if (running != null) return running;

    final future = _login(attempts);
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<AuthResult?> _login(int attempts) async {
    const backoff = [Duration.zero, Duration(seconds: 2), Duration(seconds: 5)];

    for (var attempt = 0; attempt < attempts; attempt++) {
      final pause = backoff[attempt.clamp(0, backoff.length - 1)];
      if (pause > Duration.zero) await Future<void>.delayed(pause);

      try {
        final deviceId = await _ensureDeviceId();
        final device = await const DeviceIdService().describe();
        final result = await _ref.read(authRepositoryProvider).deviceLogin(
              deviceId,
              deviceName: device.name,
              platform: device.platform,
            );
        await apply(result);
        lastError = null;
        return result;
      } catch (e) {
        lastError = e;
        // Молчать нельзя: без строки в логе пустой JWT неотличим от исправной
        // работы, и диагностика вырождается в перебор гипотез.
        debugPrint(
          '[auth] вход по device_id не удался '
          '(попытка ${attempt + 1}/$attempts): ${describeBackendError(e)}',
        );
        // Отказ сервера (401/403/422) повторять бессмысленно — ответ не
        // изменится. Повторяем только то, что похоже на сбой связи.
        if (!_isNetworkFailure(e)) break;
      }
    }
    return null;
  }

  /// Раскладывает результат входа по настройкам. Единственное место записи
  /// сессии — иначе `public_id` и статус подписки разъезжаются между экранами.
  Future<void> apply(AuthResult result) async {
    await _ref.read(Preferences.jwtToken.notifier).update(result.jwt);
    await _ref.read(Preferences.authCompleted.notifier).update(true);
    await _ref.read(Preferences.promoUsed.notifier).update(result.promoUsed);
    await _ref.read(Preferences.hasActiveSub.notifier).update(result.hasActiveSub);
    if (result.publicId != null) {
      await _ref.read(Preferences.publicId.notifier).update('${result.publicId}');
    }
  }

  /// Возвращает `device_id`, сохраняя уже выданный.
  ///
  /// ⚠️ Сохранённый id НЕ пересчитываем по новой формуле. У всех, кто уже
  /// установил приложение, в настройках лежит UUID из старой версии; пересчёт
  /// сделал бы их новыми пользователями и отобрал бы оплаченные подписки.
  Future<String> _ensureDeviceId() async {
    var id = _ref.read(Preferences.deviceId);
    if (id.isEmpty) {
      id = await const DeviceIdService().compute();
      await _ref.read(Preferences.deviceId.notifier).update(id);
    }
    return id;
  }
}

final backendSessionProvider = Provider<BackendSession>(BackendSession.new);

/// Похоже ли на сбой связи, а не на осмысленный отказ сервера.
bool isNetworkFailure(Object error) => _isNetworkFailure(error);

bool _isNetworkFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.unknown =>
      true,
    DioExceptionType.badResponse ||
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel =>
      false,
  };
}
