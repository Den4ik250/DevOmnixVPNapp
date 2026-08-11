import 'package:dio/dio.dart';
import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/features/auth/data/telegram_link_payload.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 🔴 `connectTimeout` обязателен. Голый `Dio()` его не имеет: если TCP до
/// бэкенда уходит в молчание (не «отказано», а чёрная дыра), `await` не
/// вернётся и исключения не будет — `sendTimeout`/`receiveTimeout` на этой
/// стадии ещё не работают. Экран просто зависал без ошибки.
///
/// Свой Dio, а не общий `backendDioProvider`: общий на 401 сам идёт логиниться,
/// и вход через него закольцевался бы сам на себя.
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(
    Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 10),
    )),
  ),
);

class AuthResult {
  const AuthResult({
    required this.jwt,
    required this.userId,
    required this.hasActiveSub,
    this.publicId,
    this.freeDayUsed = false,
    this.promoUsed = false,
    this.merged = false,
    this.deviceSwitched = false,
    this.phoneConflict,
  });

  final String jwt;
  final int userId;

  /// 10-значный ID, который пользователь видит в Профиле и называет в поддержке.
  final int? publicId;
  final bool freeDayUsed;
  final bool promoUsed;
  final bool hasActiveSub;

  /// Аккаунты приложения и Telegram были объединены (кейсы T2/T6).
  final bool merged;

  /// Подписка переехала на это устройство, старое разлогинено (кейс T4).
  final bool deviceSwitched;

  /// Расхождение номера — кейс T5.
  final PhoneConflict? phoneConflict;

  /// `/auth/link` не возвращает free_day_used и promo_used, поэтому оба поля
  /// читаются мягко — иначе привязка падала бы на разборе ответа.
  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        jwt: json['jwt'] as String,
        userId: json['user_id'] as int,
        publicId: json['public_id'] as int?,
        freeDayUsed: json['free_day_used'] as bool? ?? false,
        promoUsed: json['promo_used'] as bool? ?? false,
        hasActiveSub: json['has_active_sub'] as bool? ?? false,
        merged: json['merged'] as bool? ?? false,
        deviceSwitched: json['device_switched'] as bool? ?? false,
        phoneConflict: PhoneConflict.fromJson(json['phone_conflict']),
      );
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// [deviceName] и [platform] бэкенд кладёт в `device_sessions` — по ним
  /// человек узнаёт свои телефоны в кабинете, а поддержка понимает, о каком
  /// устройстве речь. Оба поля необязательны: старые версии приложения их не
  /// шлют, и вход обязан работать без них.
  Future<AuthResult> deviceLogin(
    String deviceId, {
    String? deviceName,
    String? platform,
  }) async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/device',
      data: {
        'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
        if (platform != null) 'platform': platform,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Привязка Telegram из deeplink'а. Бэкенд сам разбирает кейсы T1–T6.
  Future<AuthResult> linkTelegram({
    required TelegramLinkPayload payload,
    required String deviceId,
    bool force = false,
    bool confirmPhone = false,
  }) async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/link',
      data: {
        ...payload.toRequestJson(),
        'device_id': deviceId,
        'force': force,
        'confirm_phone': confirmPhone,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Одноразовый токен для перехода в бота: `t.me/DevOmnixVPNBot?start=link_{token}`.
  Future<String> createLinkToken(String jwt) async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/link-token',
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return (response.data as Map<String, dynamic>)['token'] as String;
  }

  Future<void> sendSmsCode(String phone, String jwt) async {
    await _dio.post(
      '${Constants.backendBaseUrl}/auth/phone/send',
      data: {'phone': phone},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<AuthResult> verifySmsCode(String phone, String code, String jwt) async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/phone/verify',
      data: {'phone': phone, 'code': code},
      options: Options(
        headers: {'Authorization': 'Bearer $jwt'},
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }
}
