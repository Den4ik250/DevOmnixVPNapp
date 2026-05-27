import 'package:dio/dio.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/data/auth_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

enum AuthStatus { loading, ready, phoneEntry, smsPending, smsVerifying, success, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.loading,
    this.promoUsed = false,
    this.hasActiveSub = false,
    this.phone,
    this.errorMessage,
  });

  final AuthStatus status;
  final bool promoUsed;
  final bool hasActiveSub;
  final String? phone;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    bool? promoUsed,
    bool? hasActiveSub,
    String? phone,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        promoUsed: promoUsed ?? this.promoUsed,
        hasActiveSub: hasActiveSub ?? this.hasActiveSub,
        phone: phone ?? this.phone,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository(Dio()));

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState());

  final Ref _ref;

  /// Called once on app startup — silently authenticates via device_id.
  Future<void> init() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final deviceId = await _ensureDeviceId();
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.deviceLogin(deviceId);
      await _applyResult(result);
      state = AuthState(
        status: AuthStatus.ready,
        promoUsed: result.promoUsed,
        hasActiveSub: result.hasActiveSub,
      );
    } catch (e) {
      // Allow offline mode — treat as no active sub
      await _ref.read(Preferences.authCompleted.notifier).update(true);
      state = const AuthState(status: AuthStatus.ready, hasActiveSub: false);
    }
  }

  /// Start phone verification flow.
  Future<void> sendSmsCode(String phone) async {
    state = state.copyWith(status: AuthStatus.smsPending, phone: phone, errorMessage: null);
    try {
      final jwt = _ref.read(Preferences.jwtToken);
      final repo = _ref.read(authRepositoryProvider);
      await repo.sendSmsCode(phone, jwt);
      state = state.copyWith(status: AuthStatus.smsVerifying);
    } catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(status: AuthStatus.phoneEntry, errorMessage: msg);
    }
  }

  /// Verify SMS code and activate promo.
  Future<void> verifySmsCode(String code) async {
    final phone = state.phone;
    if (phone == null) return;
    state = state.copyWith(status: AuthStatus.smsPending, errorMessage: null);
    try {
      final jwt = _ref.read(Preferences.jwtToken);
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.verifySmsCode(phone, code, jwt);
      await _applyResult(result);
      state = AuthState(
        status: AuthStatus.success,
        promoUsed: result.promoUsed,
        hasActiveSub: result.hasActiveSub,
      );
    } catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(status: AuthStatus.smsVerifying, errorMessage: msg);
    }
  }

  void startPhoneEntry() => state = state.copyWith(status: AuthStatus.phoneEntry, errorMessage: null);

  void backToPhoneEntry() => state = state.copyWith(status: AuthStatus.phoneEntry, errorMessage: null);

  Future<String> _ensureDeviceId() async {
    var id = _ref.read(Preferences.deviceId);
    if (id.isEmpty) {
      id = const Uuid().v4();
      await _ref.read(Preferences.deviceId.notifier).update(id);
    }
    return id;
  }

  Future<void> _applyResult(AuthResult result) async {
    await _ref.read(Preferences.jwtToken.notifier).update(result.jwt);
    await _ref.read(Preferences.authCompleted.notifier).update(true);
    await _ref.read(Preferences.promoUsed.notifier).update(result.promoUsed);
    await _ref.read(Preferences.hasActiveSub.notifier).update(result.hasActiveSub);
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      return detail?.toString() ?? e.message ?? 'Ошибка соединения';
    }
    return e.toString();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
