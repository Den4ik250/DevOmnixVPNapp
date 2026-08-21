/// Данные из deeplink'а `devomnix://auth`, которым бот передаёт Telegram-аккаунт.
///
/// Формат (Авторизация.md):
/// `devomnix://auth?tg_id=X&username=Y&first_name=N&phone=Z&ts=N&sig=HMAC`
///
/// ⚠️ Подпись здесь НЕ проверяется и проверяться не должна — это бессмысленно.
/// Кто хочет подделать привязку, обратится к API напрямую, минуя приложение.
/// Единственная настоящая проверка живёт на бэкенде
/// (`core/security.verify_link_signature`); приложение подпись только
/// переносит.
class TelegramLinkPayload {
  const TelegramLinkPayload({
    required this.telegramId,
    required this.ts,
    required this.sig,
    this.username,
    this.firstName,
    this.phone,
  });

  final int telegramId;
  final int ts;
  final String sig;
  final String? username;

  /// Имя из профиля Telegram. Подписью не покрыто — как и `username`:
  /// подделка имени ничего не даёт, а включение в HMAC ломало бы привязку
  /// всем, кто переименовался между выдачей ссылки и переходом по ней.
  final String? firstName;
  final String? phone;

  /// Разбирает ссылку. `null` — если это не наш auth-deeplink или в нём
  /// нет обязательных полей.
  static TelegramLinkPayload? tryParse(Uri uri) {
    if (uri.scheme != 'devomnix' || uri.host != 'auth') return null;

    final tgId = int.tryParse(uri.queryParameters['tg_id'] ?? '');
    final ts = int.tryParse(uri.queryParameters['ts'] ?? '');
    final sig = uri.queryParameters['sig'];
    if (tgId == null || ts == null || sig == null || sig.isEmpty) return null;

    final phone = uri.queryParameters['phone'];
    final username = uri.queryParameters['username'];
    final firstName = uri.queryParameters['first_name'];
    return TelegramLinkPayload(
      telegramId: tgId,
      ts: ts,
      sig: sig,
      username: (username == null || username.isEmpty) ? null : username,
      firstName: (firstName == null || firstName.isEmpty) ? null : firstName,
      phone: (phone == null || phone.isEmpty) ? null : phone,
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'telegram_id': telegramId,
        'ts': ts,
        'sig': sig,
        if (username != null) 'username': username,
        if (firstName != null) 'first_name': firstName,
        if (phone != null) 'phone': phone,
      };
}

/// Расхождение номера телефона — кейс T5, требует вопроса пользователю.
class PhoneConflict {
  const PhoneConflict({required this.code, this.current, this.incoming});

  final String code;
  final String? current;
  final String? incoming;

  /// Номер в Telegram отличается от номера в аккаунте — можно обновить.
  bool get canConfirm => code == 'phone_differs';

  /// Номер занят другим аккаунтом — обновить нельзя, только в поддержку.
  bool get isTaken => code == 'phone_taken';

  static PhoneConflict? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code']?.toString();
    if (code == null) return null;
    return PhoneConflict(
      code: code,
      current: raw['current']?.toString(),
      incoming: raw['incoming']?.toString(),
    );
  }
}
