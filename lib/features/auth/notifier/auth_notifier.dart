import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/backend/backend_error.dart';
import 'package:devomnix/features/auth/data/auth_repository.dart';
import 'package:devomnix/features/auth/data/device_id_service.dart';
import 'package:devomnix/features/auth/data/telegram_link_payload.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Результат привязки Telegram: либо успех, либо вопрос к пользователю.
class LinkOutcome {
  const LinkOutcome({this.result, this.conflictCode, this.conflictMessage});

  final AuthResult? result;
  final String? conflictCode;
  final String? conflictMessage;

  bool get isSuccess => result != null;

  /// T3: устройство привязано к другому Telegram — нужен вопрос
  /// «Выйти и войти заново?» и повтор с force.
  bool get needsForce => conflictCode == 'telegram_mismatch';

  /// T5: номер в Telegram отличается от номера в аккаунте.
  PhoneConflict? get phoneConflict => result?.phoneConflict;
}

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

/// 🔴 `connectTimeout` обязателен. Голый `Dio()` его не имеет: если TCP до
/// бэкенда уходит в молчание (не «отказано», а чёрная дыра), `await` не
/// вернётся и исключения не будет — `sendTimeout`/`receiveTimeout` на этой
/// стадии ещё не работают. Экран просто зависал без ошибки.
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(
    Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    )),
  ),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState());

  final Ref _ref;

  /// Called once on app startup — silently authenticates via device_id.
  Future<void> init() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final deviceId = await _ensureDeviceId();
      // Модель и платформу шлём при каждом входе, а не только при первом:
      // человек меняет телефон, и запись об устройстве должна успевать.
      final device = await const DeviceIdService().describe();
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.deviceLogin(
        deviceId,
        deviceName: device.name,
        platform: device.platform,
      );
      await _applyResult(result);
      state = AuthState(
        status: AuthStatus.ready,
        promoUsed: result.promoUsed,
        hasActiveSub: result.hasActiveSub,
      );
    } catch (e) {
      // Молчать здесь нельзя. Офлайн-режим внешне неотличим от исправной
      // работы: JWT пустой, public_id пустой, все экраны отдают «ошибка
      // загрузки» — и ни одной строки о причине. Именно на этом застряла
      // диагностика «приложение не видит бэкенд».
      debugPrint('[auth] вход по device_id не удался: ${describeBackendError(e)}');
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

  /// Возвращает device_id, сохраняя уже выданный.
  ///
  /// ⚠️ Сохранённый id НЕ пересчитываем по новой формуле. У всех, кто уже
  /// установил приложение, в настройках лежит UUID из старой версии; пересчёт
  /// сделал бы их новыми пользователями и отобрал бы оплаченные подписки.
  /// Новая формула работает только для чистых установок.
  Future<String> _ensureDeviceId() async {
    var id = _ref.read(Preferences.deviceId);
    if (id.isEmpty) {
      id = await const DeviceIdService().compute();
      await _ref.read(Preferences.deviceId.notifier).update(id);
    }
    return id;
  }

  /// Привязка Telegram-аккаунта из deeplink'а `devomnix://auth` (кейсы T1–T6).
  ///
  /// [force] — пользователь подтвердил «Выйти и войти заново» (T3).
  /// [confirmPhone] — пользователь подтвердил смену номера (T5).
  Future<LinkOutcome> linkTelegram(
    TelegramLinkPayload payload, {
    bool force = false,
    bool confirmPhone = false,
  }) async {
    final deviceId = await _ensureDeviceId();
    final repo = _ref.read(authRepositoryProvider);
    try {
      final result = await repo.linkTelegram(
        payload: payload,
        deviceId: deviceId,
        force: force,
        confirmPhone: confirmPhone,
      );
      await _applyResult(result);
      state = AuthState(
        status: AuthStatus.success,
        promoUsed: state.promoUsed,
        hasActiveSub: result.hasActiveSub,
      );
      return LinkOutcome(result: result);
    } on DioException catch (e) {
      // 409 — не ошибка связи, а вопрос к пользователю: чужой Telegram (T3).
      // Экран должен показать диалог и повторить вызов с force.
      final detail = e.response?.data?['detail'];
      if (e.response?.statusCode == 409 && detail is Map) {
        return LinkOutcome(
          conflictCode: detail['code']?.toString(),
          conflictMessage: detail['message']?.toString(),
        );
      }
      return LinkOutcome(conflictMessage: _extractError(e));
    } catch (e) {
      return LinkOutcome(conflictMessage: _extractError(e));
    }
  }

  Future<void> _applyResult(AuthResult result) async {
    await _ref.read(Preferences.jwtToken.notifier).update(result.jwt);
    await _ref.read(Preferences.authCompleted.notifier).update(true);
    await _ref.read(Preferences.promoUsed.notifier).update(result.promoUsed);
    await _ref.read(Preferences.hasActiveSub.notifier).update(result.hasActiveSub);
    if (result.publicId != null) {
      await _ref.read(Preferences.publicId.notifier).update('${result.publicId}');
    }
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
