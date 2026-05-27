import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/home/notifier/installed_apps_provider.dart';
import 'package:devomnix/features/home/widget/app_picker_sheet.dart';
import 'package:devomnix/features/per_app_proxy/data/app_proxy_data_source.dart';
import 'package:devomnix/features/per_app_proxy/data/selected_data_provider.dart';
import 'package:devomnix/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:devomnix/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SplitTunnelCard extends ConsumerWidget {
  const SplitTunnelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!PlatformUtils.isAndroid) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final mode = ref.watch(Preferences.perAppProxyMode);
    final isProxy = mode == PerAppProxyMode.include;
    final selectedPkgs = ref.watch(Preferences.includeApps);
    final appsMap = ref.watch(installedUserAppsProvider).valueOrNull ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // VPN / ПРОКСИ toggle
          SegmentedButton<PerAppProxyMode>(
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
            // Map exclude (set via old settings UI) to the "off" segment so toggle still makes sense
            selected: {isProxy ? PerAppProxyMode.include : PerAppProxyMode.off},
            onSelectionChanged: (modes) async {
              await ref.read(Preferences.perAppProxyMode.notifier).update(modes.first);
            },
          ),

          // App-list card — only in proxy mode
          if (isProxy) ...[
            const Gap(8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

                  // Empty hint
                  if (selectedPkgs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        'Добавьте приложения — их трафик пойдёт через прокси,\nостальное напрямую.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    // App rows
                    ...selectedPkgs.map(
                      (pkg) => _AppRow(
                        packageName: pkg,
                        appName: appsMap[pkg]?.name,
                        icon: appsMap[pkg]?.icon,
                        onRemove: () => ref.read(appProxyDataSourceProvider).updatePkg(
                          pkg: pkg,
                          mode: AppProxyMode.include,
                        ),
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
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.06),
          ],
        ],
      ),
    );
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
              child: Image.memory(icon!, width: 36, height: 36, cacheWidth: 36, cacheHeight: 36),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.android_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
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
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
