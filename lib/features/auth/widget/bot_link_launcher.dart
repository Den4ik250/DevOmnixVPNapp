import 'package:flutter/material.dart';
import 'package:devomnix/core/model/constants.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Открывает бота с одноразовым токеном привязки (кейс A1).
///
/// Без токена бот не поймёт, к какому аккаунту приложения цеплять Telegram, —
/// у него есть только tg_id. Токен живёт 5 минут и гасится при первом
/// предъявлении, поэтому берём его непосредственно перед переходом.
Future<void> openBotWithLink(BuildContext context, WidgetRef ref) async {
  // Токен получаем первым, но его неудача переход не отменяет: в боте есть
  // оплата и поддержка, они полезны и без привязки.
  String? token;
  try {
    final jwt = ref.read(Preferences.jwtToken);
    token = await ref.read(authRepositoryProvider).createLinkToken(jwt);
  } catch (_) {
    token = null;
  }

  final opened = await _launchBot(token);
  if (!opened && context.mounted) {
    // Раньше оба провала `canLaunchUrl` проглатывались молча, и кнопка
    // выглядела сломанной. Пусть лучше скажет, что не смогла.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть Telegram')),
    );
  }
}

/// Пробует открыть бота: сначала приложением Telegram, потом ссылкой.
///
/// 🔴 Порядок важен. `https://t.me/...` на Android уходит тому, кто заявлен
/// обработчиком ссылки, и если у Telegram не подтверждены App Links, человек
/// попадает на веб-страницу t.me вместо бота — выглядит как «кнопка ведёт
/// в никуда». `tg://resolve` открывает клиент напрямую.
///
/// https остаётся запасным путём (Telegram не установлен) и менять его нельзя:
/// именно эта ссылка зафиксирована при согласовании в Platega.
Future<bool> _launchBot(String? token) async {
  const botUrl = Constants.vpnBotUrl;
  final botName = Uri.parse(botUrl).pathSegments.last;
  final start = token == null ? null : 'link_$token';

  final candidates = <Uri>[
    Uri.parse('tg://resolve?domain=$botName'
        '${start == null ? '' : '&start=$start'}'),
    Uri.parse('$botUrl${start == null ? '' : '?start=$start'}'),
  ];

  for (final uri in candidates) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // ActivityNotFoundException при отсутствии Telegram — пробуем следующий
    }
  }
  return false;
}
