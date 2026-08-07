import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Как устройство называется в личном кабинете и в поддержке.
///
/// Отдельно от `device_id`: тот — необратимый хеш, по нему человека не
/// опознать. Здесь читаемые модель и платформа, которые видит и сам
/// пользователь, и оператор поддержки.
class DeviceDescription {
  const DeviceDescription({this.name, required this.platform});

  /// Модель в человеческом виде: «samsung SM-A515F», «iPhone14,3».
  /// `null`, если ОС не отдала — поле в БД nullable, это допустимо.
  final String? name;

  /// `android` | `ios` | `windows` | `macos` | `linux`.
  final String platform;
}

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

  /// Ограничение колонки `device_sessions.device_name` — VARCHAR(128).
  static const _maxNameLength = 128;

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

  /// Читаемое описание устройства для отправки при входе.
  ///
  /// Никогда не бросает: вход по device_id важнее, чем модель телефона, а
  /// исключение отсюда увело бы `AuthNotifier.init()` в офлайн-режим и
  /// оставило человека без аккаунта.
  Future<DeviceDescription> describe() async {
    final platform = Platform.operatingSystem;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return _describe('${info.manufacturer} ${info.model}', platform);
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        // `utsname.machine` — точный идентификатор модели («iPhone14,3»).
        // `info.name` на iOS 16+ обезличен до «iPhone» и поддержке бесполезен.
        return _describe(info.utsname.machine, platform);
      }
      if (Platform.isWindows) {
        return _describe((await plugin.windowsInfo).computerName, platform);
      }
      if (Platform.isMacOS) {
        return _describe((await plugin.macOsInfo).model, platform);
      }
      if (Platform.isLinux) {
        return _describe((await plugin.linuxInfo).prettyName, platform);
      }
    } catch (_) {
      // Модель — приятное дополнение, а не условие входа.
    }
    return DeviceDescription(platform: platform);
  }

  DeviceDescription _describe(String rawName, String platform) {
    final name = rawName.trim();
    return DeviceDescription(
      name: name.isEmpty
          ? null
          : (name.length > _maxNameLength ? name.substring(0, _maxNameLength) : name),
      platform: platform,
    );
  }

  String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();
}
