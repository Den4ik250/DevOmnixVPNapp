import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class Constants {
  static const appName = "DevOmnix VPN";
  static const githubUrl = "https://github.com/Den4ik250/DevOmnixVPNapp";
  static const licenseUrl = "https://github.com/Den4ik250/DevOmnixVPNapp?tab=License-1-ov-file#readme";
  static const githubReleasesApiUrl = "https://api.github.com/repos/Den4ik250/DevOmnixVPNapp/releases";
  static const githubLatestReleaseUrl = "https://github.com/Den4ik250/DevOmnixVPNapp/releases/latest";
  static const appCastUrl = "https://raw.githubusercontent.com/Den4ik250/DevOmnixVPNapp/main/appcast.xml";
  static const telegramChannelUrl = "https://t.me/devomnix";
  /// Бот поддержки. Отдельный от канала компании и от VPN-бота — не путать.
  static const supportBotUrl = "https://t.me/DevOmnixSupportBot";
  /// VPN-бот. ⚠️ Ссылка зафиксирована при согласовании в Platega —
  /// менять нельзя, иначе пересогласование проекта в банке.
  static const vpnBotUrl = "https://t.me/DevOmnixVPNBot";
  // Документы живут на telegra.ph — их же адреса заявлены в BotFather и в Platega.
  // Менять только вместе с ботом и менеджером кассы: смена ссылок = пересогласование.
  static const privacyPolicyUrl = "https://telegra.ph/Politika-konfidencialnosti-08-01-68";
  static const termsAndConditionsUrl = "https://telegra.ph/Polzovatelskoe-soglashenie-08-01-30";
  static const cfWarpPrivacyPolicy = "https://www.cloudflare.com/application/privacypolicy/";
  static const cfWarpTermsOfService = "https://www.cloudflare.com/application/terms/";

  // DevOmnix backend
  //
  // 🔴 Порт 80, а НЕ 8000. Проверено 07.08.2026: с телефона TCP до :8000 уходит
  // в таймаут (errno 110 — пакеты дропаются молча), потому что нестандартные
  // порты режут операторы и публичные точки доступа. На :80 стоит nginx,
  // проксирующий тот же API — все методы, включая POST и авторизованные.
  // Из-за :8000 приложение двое суток выглядело сломанным: браузер по другой
  // сети открывался, а запросы из приложения не доходили.
  //
  // ⚠️ 20.08.2026 — переезд на 136.148.216.141 (Time4VPS, Stockholm).
  // nginx на новом сервере ещё НЕ поднят: :80 уходит в таймаут, API отвечает
  // только на :8000. Порт здесь оставлен 80 намеренно — адрес заработает сам,
  // как только на сервере применят deploy/nginx-devomnix.conf из репозитория
  // бэкенда. Прописывать сюда :8000 нельзя: это ровно та конфигурация,
  // которая уже ломала приложение у мобильных операторов (см. выше).
  //
  // TODO: перевести на https://api.devomnix.com после настройки DNS и TLS.
  static const backendBaseUrl = "http://136.148.216.141";

  /// Имя профиля, который приложение скачивает у бэкенда само.
  ///
  /// По нему авто-профиль отличается от серверов, которые человек добавил
  /// вручную своей vless-строкой. Разница принципиальная: подписка даёт доступ
  /// к НАШЕМУ серверу, а к своему человек ходит без нашего разрешения.
  ///
  /// Лежит здесь, а не рядом с `VpnAutoInitNotifier`, чтобы на константу мог
  /// сослаться и `SubscriptionGuard`, не заводя кольцо импортов.
  static const autoProfileName = "DevOmnix VPN";
}

const kAnimationDuration = Duration(milliseconds: 250);

abstract class AddProfileModalConst {
  static const fixBtnsGap = 16.0;
  static const fixBtnsGapCount = 4;
  static const fixBtnsItemCount = 3;
  static const navBarGap = 16.0;
  static const navBarBottomGap = 4.0;
  //switch default height
  static const navBarcontentHeight = 32.0;
  static const navBarHeight = navBarGap + navBarBottomGap + navBarcontentHeight;
}

abstract class AlertDialogConst {
  static const minWidth = 280.0;
  static const maxWidth = 560.0;
  static const boxConstraints = BoxConstraints(minWidth: minWidth, maxWidth: maxWidth);
}

abstract class BottomSheetConst {
  static const maxWidth = 456.0;
  static const boxConstraints = BoxConstraints(maxWidth: maxWidth);
  static const borderRadius = BorderRadius.vertical(top: Radius.circular(32));
}

abstract class ProfileTileConst {
  static const radius = Radius.circular(16);
  static const cardBorderRadius = BorderRadius.all(radius);
  static const borderRadiusRight = BorderRadius.horizontal(right: radius);
  static const borderRadiusLeft = BorderRadius.horizontal(left: radius);
  static BorderRadius startBorderRadius(TextDirection direction) =>
      direction == TextDirection.ltr ? borderRadiusLeft : borderRadiusRight;
  static BorderRadius endBorderRadius(TextDirection direction) =>
      direction == TextDirection.ltr ? borderRadiusRight : borderRadiusLeft;
}

abstract class IntroConst {
  static const maxwidth = 620;
  static const termsAndConditionsKey = 'terms-and-conditions';
  static const githubKey = 'github';
  static const licenseKey = 'license';
  static const url = <String, String>{IntroConst.termsAndConditionsKey: Constants.termsAndConditionsUrl, IntroConst.githubKey: Constants.githubUrl, IntroConst.licenseKey: Constants.licenseUrl};
}

abstract class WarpConst {
  static const warpAccountId = 'warp-account-id';
  static const warpAccessToken = "warp-access-token";
  static const warpConsentGiven = "warp-consent-given";
  static const warpTermsOfServiceKey = 'warp-terms-of-service';
  static const warpPrivacyPolicyKey = 'warp-privacy-policy';
  static const url = <String, String>{WarpConst.warpTermsOfServiceKey: Constants.cfWarpTermsOfService, WarpConst.warpPrivacyPolicyKey: Constants.cfWarpPrivacyPolicy};
}

abstract class KeyboardConst {
  static final allArrows = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight};
  static final horizontalArrows = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight};
  static final verticalArrows = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown};
  static final select = {LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.tab};
}
