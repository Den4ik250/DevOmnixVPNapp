import 'package:dio/dio.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Dio instance pre-configured with JWT bearer token.
final backendDioProvider = Provider<Dio>((ref) {
  final jwt = ref.watch(Preferences.jwtToken);
  final dio = Dio(BaseOptions(
    baseUrl: Constants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  if (jwt.isNotEmpty) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $jwt';
          handler.next(options);
        },
      ),
    );
  }
  return dio;
});
