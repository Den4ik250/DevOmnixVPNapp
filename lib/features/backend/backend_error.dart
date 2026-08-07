import 'package:dio/dio.dart';

/// Человекочитаемая причина отказа запроса к бэкенду.
///
/// Экраны раньше показывали только «Не удалось загрузить», и по такому тексту
/// нельзя отличить обрыв соединения от 401 или от ошибки разбора JSON —
/// диагностика упиралась в это. Здесь достаточно деталей, чтобы пользователь
/// мог просто прочитать строку вслух.
String describeBackendError(Object error) {
  if (error is! DioException) return error.toString();

  final uri = error.requestOptions.uri;
  final code = error.response?.statusCode;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return 'Таймаут подключения к $uri — TCP-соединение не установилось.';
    case DioExceptionType.connectionError:
      return 'Нет соединения с $uri: ${error.error}';
    case DioExceptionType.sendTimeout:
      return 'Таймаут отправки запроса на $uri.';
    case DioExceptionType.receiveTimeout:
      return 'Соединение с $uri установлено, но ответ не пришёл вовремя.';
    case DioExceptionType.badCertificate:
      return 'Сертификат отклонён: $uri';
    case DioExceptionType.cancel:
      return 'Запрос отменён: $uri';
    case DioExceptionType.badResponse:
      final body = error.response?.data?.toString() ?? '';
      final short = body.length > 200 ? '${body.substring(0, 200)}…' : body;
      return 'Сервер ответил $code на $uri. $short';
    case DioExceptionType.unknown:
      // Сюда же попадают ошибки разбора ответа — сервер при этом ответил.
      return 'Ошибка при обращении к $uri: ${error.error ?? error.message}';
  }
}
