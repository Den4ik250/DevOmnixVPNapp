import 'package:dio/dio.dart';
import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/data/device_id_service.dart';
import 'package:devomnix/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Помечает запрос, который уже переживал восстановление сессии.
/// Без метки 401 на повторе увёл бы в бесконечный цикл перелогинов.
const _retriedKey = 'devomnix_retried_after_401';

/// Dio instance pre-configured with JWT bearer token.
final backendDioProvider = Provider<Dio>((ref) {
  final jwt = ref.watch(Preferences.jwtToken);
  final dio = Dio(BaseOptions(
    baseUrl: Constants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Токен читаем на каждом запросе, а не замыкаем: после
        // самовосстановления ниже он меняется, а провайдер к этому моменту
        // ещё не пересобран.
        final token = ref.read(Preferences.jwtToken);
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 🔴 Самовосстановление сессии.
        //
        // Раньше одна неудачная попытка входа при старте оставляла приложение
        // без JWT навсегда: `AuthNotifier.init()` молча уходил в офлайн-режим,
        // и дальше КАЖДЫЙ экран получал 401 — «Тарифы», «Кошелёк», реферальная
        // программа, пинг. Внешне это неотличимо от «нет связи с сервером»,
        // и чинилось только переустановкой приложения.
        //
        // Теперь 401 сам чинит себя: вход по device_id (он переживает
        // переустановку, так что аккаунт тот же) и один повтор запроса.
        final isAuthError = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra[_retriedKey] == true;
        if (!isAuthError || alreadyRetried) {
          return handler.next(error);
        }

        final token = await _reauthenticate(ref);
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

  if (jwt.isEmpty) {
    // Пустой токен — состояние, из которого приложение раньше не выбиралось.
    // Пробуем войти заранее, не дожидаясь первого 401.
    Future.microtask(() => _reauthenticate(ref));
  }

  return dio;
});

/// Повторный вход по device_id. Возвращает свежий JWT либо null.
///
/// Никогда не бросает: это фоновое восстановление, и его отказ не должен
/// подменять собой исходную ошибку запроса — иначе пользователь увидит
/// причину «не удалось войти» вместо настоящей причины отказа.
Future<String?> _reauthenticate(Ref ref) async {
  try {
    var deviceId = ref.read(Preferences.deviceId);
    if (deviceId.isEmpty) {
      deviceId = await const DeviceIdService().compute();
      await ref.read(Preferences.deviceId.notifier).update(deviceId);
    }
    final device = await const DeviceIdService().describe();
    final result = await ref.read(authRepositoryProvider).deviceLogin(
          deviceId,
          deviceName: device.name,
          platform: device.platform,
        );
    await ref.read(Preferences.jwtToken.notifier).update(result.jwt);
    if (result.publicId != null) {
      await ref.read(Preferences.publicId.notifier).update('${result.publicId}');
    }
    return result.jwt;
  } catch (_) {
    return null;
  }
}
