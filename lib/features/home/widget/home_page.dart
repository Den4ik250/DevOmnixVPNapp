import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/promo_banner.dart';
import 'package:hiddify/features/home/widget/server_picker_sheet.dart';
import 'package:hiddify/features/home/widget/split_tunnel_card.dart';
import 'package:hiddify/features/home/widget/speed_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_card.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;

    // Trigger auto-init on mount (silently fetches VLESS config if no profile).
    ref.watch(vpnAutoInitProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Assets.images.logo.svg(height: 24),
            const Gap(8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.common.appTitle),
                  const TextSpan(text: " "),
                  const WidgetSpan(child: AppVersionLabel(), alignment: PlaceholderAlignment.middle),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/world_map.png'),
            fit: BoxFit.cover,
            opacity: 0.09,
            colorFilter: theme.brightness == Brightness.dark
                ? ColorFilter.mode(Colors.white.withValues(alpha: .15), BlendMode.srcIn)
                : ColorFilter.mode(Colors.grey.withValues(alpha: 1), BlendMode.srcATop),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              slivers: [
                MultiSliver(
                  children: [
                    const PromoBanner(),
                    const SplitTunnelCard(),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ConnectionButton(),
                                Gap(12),
                                _ServerPickerButton(),
                                SpeedIndicator(),
                                ActiveProxyDelayIndicator(),
                              ],
                            ),
                          ),
                          ActiveProxyFooter(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerPickerButton extends ConsumerWidget {
  const _ServerPickerButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switching = ref.watch(vpnAutoInitProvider).isLoading;
    final selectedId = ref.watch(selectedServerIdProvider);

    // Build label showing selected server flag if known
    final serversAsync = ref.watch(vpnServersProvider);
    String label = 'Выбрать сервер';
    if (serversAsync case AsyncData(value: final servers) when servers.isNotEmpty) {
      final server = servers.isEmpty
          ? null
          : servers.firstWhere(
              (s) => s['id'] == selectedId,
              orElse: () => servers.first,
            );
      if (server != null) {
        final flag = server['flag'] as String? ?? '';
        final country = server['country'] as String? ?? server['name'] as String;
        label = '$flag $country';
      }
    }

    return OutlinedButton.icon(
      onPressed: switching ? null : () => showServerPickerSheet(context),
      icon: switching
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.public_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();
    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
