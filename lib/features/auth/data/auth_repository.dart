import 'package:dio/dio.dart';
import 'package:devomnix/core/model/constants.dart';

class AuthResult {
  const AuthResult({
    required this.jwt,
    required this.userId,
    required this.freeDayUsed,
    required this.promoUsed,
    required this.hasActiveSub,
  });

  final String jwt;
  final int userId;
  final bool freeDayUsed;
  final bool promoUsed;
  final bool hasActiveSub;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        jwt: json['jwt'] as String,
        userId: json['user_id'] as int,
        freeDayUsed: json['free_day_used'] as bool,
        promoUsed: json['promo_used'] as bool,
        hasActiveSub: json['has_active_sub'] as bool,
      );
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthResult> deviceLogin(String deviceId) async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/device',
      data: {'device_id': deviceId},
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
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
