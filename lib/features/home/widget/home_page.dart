import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/core/app_info/app_info_provider.dart';
import 'package:devomnix/core/localization/translations.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/home/notifier/installed_apps_provider.dart';
import 'package:devomnix/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:devomnix/features/home/widget/app_picker_sheet.dart';
import 'package:devomnix/features/home/widget/connection_button.dart';
import 'package:devomnix/features/home/widget/promo_banner.dart';
import 'package:devomnix/features/home/widget/speed_indicator.dart';
import 'package:devomnix/features/per_app_proxy/data/app_proxy_data_source.dart';
import 'package:devomnix/features/per_app_proxy/data/selected_data_provider.dart';
import 'package:devomnix/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:devomnix/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:devomnix/gen/assets.gen.dart';
import 'package:devomnix/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;

    // Trigger auto-init on mount.
    ref.watch(vpnAutoInitProvider);

    final mode = ref.watch(Preferences.perAppProxyMode);
    final isProxy = mode == PerAppProxyMode.include;

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
                  const TextSpan(text: ' '),
                  const WidgetSpan(
                    child: AppVersionLabel(),
                    alignment: PlaceholderAlignment.middle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Promo banner (phone not confirmed) ──────────────────
              const PromoBanner(),

              // ── 2. VPN / Proxy toggle ──────────────────────────────────
              if (PlatformUtils.isAndroid)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _VpnProxyToggle(isProxy: isProxy, ref: ref),
                ),

              // ── 3. Center area: world map bg + connection button ───────
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // World map background
                    Image.asset(
                      'assets/images/world_map.png',
                      fit: BoxFit.cover,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: .15)
                          : Colors.grey.withValues(alpha: 1),
                      colorBlendMode: theme.brightness == Brightness.dark
                          ? BlendMode.srcIn
                          : BlendMode.srcATop,
                      opacity: const AlwaysStoppedAnimation(0.09),
                    ),

                    // Connection button + server picker centered
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConnectionButton(),
                          Gap(16),
                          SpeedIndicator(),
                          ActiveProxyDelayIndicator(),
                          Gap(16),
                          _DiagnosticsButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 4. Proxy apps block (Android, proxy mode only) ─────────
              if (PlatformUtils.isAndroid && isProxy)
                const _ProxyAppsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── VPN / Proxy segmented toggle ──────────────────────────────────────────────

class _VpnProxyToggle extends StatelessWidget {
  const _VpnProxyToggle({required this.isProxy, required this.ref});

  final bool isProxy;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PerAppProxyMode>(
      segments: const [
        ButtonSegment(
          value: PerAppProxyMode.off,
          icon: Icon(Icons.vpn_lock_rounded),
          label: Text('VPN'),
        ),
        ButtonSegment(
          value: PerAppProxyMode.include,
          icon: Icon(Icons.apps_outlined),
          label: Text('Прокси'),
        ),
      ],
      selected: {isProxy ? PerAppProxyMode.include : PerAppProxyMode.off},
      onSelectionChanged: (modes) async {
        await ref.read(Preferences.perAppProxyMode.notifier).update(modes.first);
      },
    );
  }
}

// ── Diagnostics button ─────────────────────────────────────────────────────────

class _DiagnosticsButton extends StatelessWidget {
  const _DiagnosticsButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.goNamed('diagnostics'),
      icon: const Icon(Icons.network_check_rounded, size: 16),
      label: const Text('Диагностика'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ── Proxy apps section (bottom panel) ─────────────────────────────────────────

class _ProxyAppsSection extends ConsumerWidget {
  const _ProxyAppsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedPkgs = ref.watch(Preferences.includeApps);
    final appsMap = ref.watch(installedUserAppsProvider).valueOrNull ?? {};
    final appsSource = ref.read(appProxyDataSourceProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      constraints: const BoxConstraints(maxHeight: 210),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const Gap(6),
                  Text(
                    'Приложения через прокси',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selectedPkgs.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedPkgs.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // App list or empty hint
            if (selectedPkgs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Добавьте приложения — их трафик пойдёт через прокси,\nостальное напрямую.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: selectedPkgs
                      .map(
                        (pkg) => _AppRow(
                          packageName: pkg,
                          appName: appsMap[pkg]?.name,
                          icon: appsMap[pkg]?.icon,
                          onRemove: () => appsSource.updatePkg(
                            pkg: pkg,
                            mode: AppProxyMode.include,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            const Divider(height: 1),

            // Add button
            TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const AppPickerSheet(),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить приложение'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.06);
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.packageName,
    this.appName,
    this.icon,
    required this.onRemove,
  });

  final String packageName;
  final String? appName;
  final Uint8List? icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: icon != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                icon!,
                width: 32,
                height: 32,
                cacheWidth: 32,
                cacheHeight: 32,
              ),
            )
          : Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.android_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
      title: Text(
        appName ?? packageName,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: appName != null
          ? Text(
              packageName,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        onPressed: onRemove,
        tooltip: 'Убрать',
        color: theme.colorScheme.error,
      ),
    );
  }
}

// ── App version label in AppBar ────────────────────────────────────────────────

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
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
