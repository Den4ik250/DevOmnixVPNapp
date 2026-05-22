import 'package:dio/dio.dart';
import 'package:hiddify/core/model/constants.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<({String loginToken, String botUrl})> requestLogin() async {
    final response = await _dio.post(
      '${Constants.backendBaseUrl}/auth/request-login',
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final data = response.data as Map<String, dynamic>;
    return (
      loginToken: data['login_token'] as String,
      botUrl: data['bot_url'] as String,
    );
  }

  /// Returns JWT string if auth confirmed, null if still pending.
  /// Throws DioException with 404 if token expired.
  Future<String?> checkLogin(String loginToken) async {
    final response = await _dio.get(
      '${Constants.backendBaseUrl}/auth/check/$loginToken',
      options: Options(
        validateStatus: (s) => s == 200 || s == 202,
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    if (response.statusCode == 202) return null;
    final data = response.data as Map<String, dynamic>;
    return data['jwt'] as String?;
  }
}
