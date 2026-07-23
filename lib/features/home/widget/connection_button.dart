import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/core/localization/translations.dart';
import 'package:devomnix/core/router/dialog/dialog_notifier.dart';
import 'package:devomnix/core/widget/animated_text.dart';
import 'package:devomnix/features/connection/model/connection_status.dart';
import 'package:devomnix/features/connection/model/extended_connection_status.dart';
import 'package:devomnix/features/connection/notifier/connection_notifier.dart';
import 'package:devomnix/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:devomnix/features/profile/notifier/active_profile_notifier.dart';
import 'package:devomnix/features/proxy/active/active_proxy_notifier.dart';
import 'package:devomnix/features/settings/data/config_option_repository.dart';
import 'package:devomnix/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:devomnix/gen/assets.gen.dart';
import 'package:devomnix/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    var secureLabel =
        (ref.watch(ConfigOptions.enableWarp) && ref.watch(ConfigOptions.warpDetourMode) == WarpDetourMode.warpOverProxy)
            ? t.connection.secure
            : "";
    if (delay <= 0 || delay > 65000 || connectionStatus.value != const Connected()) {
      secureLabel = "";
    }

    final extStatus = switch (connectionStatus) {
      AsyncData(value: final s) when delay > 0 && delay < 65000 && s == const Connected() =>
        ExtendedConnectionStatus.connected,
      AsyncData(value: Connected()) => ExtendedConnectionStatus.handshaking,
      AsyncData(value: final s) => ExtendedConnectionStatus.fromCoreStatus(s),
      AsyncLoading() => ExtendedConnectionStatus.waitingForNetwork,
      _ => ExtendedConnectionStatus.disconnected,
    };

    return _ConnectionButton(
      onTap: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => () async {
          final activeProfile = await ref.read(activeProfileProvider.future);
          return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
        },
        AsyncData(value: Disconnected()) || AsyncError() => () async {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            // Профиля нет локально — проверяем бэкенд
            final hasSub = await ref.read(subscriptionStatusProvider.future);
            if (!hasSub) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Нет активной подписки. Перейдите в раздел Тарифы.')),
                );
              }
              return;
            }
            // Подписка есть — скачиваем конфиг и активируем.
            // activateAndConnect ловит ошибку в AsyncValue.guard, поэтому её надо
            // явно достать из состояния — иначе сбой получения конфига выглядит
            // как «кнопка не работает».
            await ref.read(vpnAutoInitProvider.notifier).activateAndConnect();
            if (context.mounted && ref.read(vpnAutoInitProvider) is AsyncError) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось получить конфигурацию VPN. Попробуйте ещё раз.'),
                ),
              );
            }
            return;
          }
          if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
          }
        },
        AsyncData(value: Connected()) => () async {
          if (requiresReconnect == true &&
              await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref
                .read(connectionNotifierProvider.notifier)
                .reconnect(await ref.read(activeProfileProvider.future));
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        _ => () {},
      },
      enabled: switch (connectionStatus) {
        AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
        _ => false,
      },
      label: requiresReconnect == true && connectionStatus.value == const Connected()
          ? t.connection.reconnect
          : extStatus.label,
      extStatus: extStatus,
      animated: extStatus.isActive || extStatus.isConnected,
      secureLabel: secureLabel,
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.extStatus,
    required this.animated,
    required this.secureLabel,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final ExtendedConnectionStatus extStatus;
  final bool animated;
  final String secureLabel;

  static const _brandBlue = Color(0xFF4499FF);
  static const _brandCyan = Color(0xFF00CCFF);
  static const _connGreen1 = Color(0xFF22C55E);
  static const _connGreen2 = Color(0xFF16A34A);

  (Color, Color) get _hexColors => extStatus.isConnected
      ? (_connGreen1, _connGreen2)
      : (_brandBlue, _brandCyan);

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = _hexColors;

    Widget hexButton = SizedBox(
      width: 148,
      height: 148,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: c1),
          duration: const Duration(milliseconds: 400),
          builder: (context, animC1, _) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: c2),
            duration: const Duration(milliseconds: 400),
            builder: (context, animC2, _) => CustomPaint(
              painter: _HexPainter(color1: animC1 ?? c1, color2: animC2 ?? c2),
              child: Center(
                child: Assets.images.logo.svg(
                  width: 68,
                  height: 68,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (extStatus.isActive) {
      hexButton = hexButton
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.93, end: 1.0, duration: 850.ms, curve: Curves.easeInOut);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: hexButton,
        ),
        const Gap(16),
        ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText(label, style: Theme.of(context).textTheme.titleMedium),
              if (secureLabel.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.shieldHalved, size: 16, color: Theme.of(context).colorScheme.secondary),
                    const Gap(4),
                    Text(
                      secureLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  const _HexPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Leave 8px margin for the glow shadow to not get clipped
    final r = size.width / 2 - 8;
    final path = _hexPath(cx, cy, r);

    // Glow shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = color1.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Gradient fill
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ).createShader(rect),
    );
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Pointy-top hexagon: first vertex at top (-90°)
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color1 != color1 || old.color2 != color2;
}
