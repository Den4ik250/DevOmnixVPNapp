import 'package:dio/dio.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/auth/data/auth_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum AuthStatus { idle, loading, waitingForBot, success, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.botUrl,
  });

  final AuthStatus status;
  final String? errorMessage;
  final String? botUrl;
}

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository(Dio()));

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState());

  final Ref _ref;

  Future<void> startLogin() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.requestLogin();
      state = AuthState(status: AuthStatus.waitingForBot, botUrl: result.botUrl);
      await launchUrl(Uri.parse(result.botUrl), mode: LaunchMode.externalApplication);
      _pollForJwt(result.loginToken);
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data?['detail'] ?? e.message)
          : e.toString();
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: msg?.toString() ?? 'Ошибка соединения',
      );
    }
  }

  Future<void> _pollForJwt(String loginToken) async {
    for (var i = 0; i < 150; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (state.status != AuthStatus.waitingForBot) return;
      try {
        final repo = _ref.read(authRepositoryProvider);
        final jwt = await repo.checkLogin(loginToken);
        if (jwt != null) {
          await _ref.read(Preferences.jwtToken.notifier).update(jwt);
          await _ref.read(Preferences.authCompleted.notifier).update(true);
          if (mounted) state = const AuthState(status: AuthStatus.success);
          return;
        }
      } catch (e) {
        if (e is DioException && (e.response?.statusCode == 404)) {
          if (mounted) {
            state = const AuthState(
              status: AuthStatus.error,
              errorMessage: 'Время ожидания истекло. Попробуйте снова.',
            );
          }
          return;
        }
      }
    }
    if (mounted) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Время ожидания истекло. Попробуйте снова.',
      );
    }
  }

  void reset() => state = const AuthState();
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
