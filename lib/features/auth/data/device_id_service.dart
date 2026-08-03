import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Идентификатор устройства по спеке Авторизация.md.
///
/// Android: `SHA-256(ANDROID_ID + модель)`, iOS: `SHA-256(IDFV + модель)`.
/// Смысл в том, что он переживает переустановку приложения — сохранённый
/// UUID из настроек при переустановке терялся, и человек возвращался уже
/// новым пользователем, без своей подписки.
///
/// Сбрасывается только при сбросе телефона до заводских настроек.
class DeviceIdService {
  const DeviceIdService();

  /// Считает device_id для текущего устройства.
  ///
  /// На неподдерживаемых платформах и при отказе ОС отдавать идентификатор
  /// откатываемся на случайный UUID: лучше новый аккаунт, чем неработающее
  /// приложение. Такой id не переживёт переустановку — это осознанный размен.
  Future<String> compute() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return _hash('${info.id}${info.model}');
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final idfv = info.identifierForVendor;
        if (idfv != null && idfv.isNotEmpty) {
          return _hash('$idfv${info.model}');
        }
      }
    } catch (_) {
      // Падать здесь нельзя — без device_id приложение вообще не стартует.
    }
    return const Uuid().v4();
  }

  String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();
}
