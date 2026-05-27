import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:devomnix/core/localization/translations.dart';
import 'package:devomnix/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:devomnix/core/router/dialog/dialog_notifier.dart';
import 'package:devomnix/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:devomnix/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:devomnix/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:devomnix/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: ListView(
        children: [
          SettingsSection(
            title: t.pages.settings.general.title,
            icon: Icons.settings_rounded,
            namedLocation: context.namedLocation('general'),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_rounded),
            title: const Text('Добавить свои настройки'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showAddConfigSheet(context, ref),
          ),
          // ── Visible only in debug builds ──────────────────────────────────
          if (kDebugMode) ...[
            const Divider(),
            SettingsSection(
              title: t.pages.settings.routing.title,
              icon: Icons.route_rounded,
              namedLocation: context.namedLocation('routeOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.dns.title,
              icon: Icons.dns_rounded,
              namedLocation: context.namedLocation('dnsOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.inbound.title,
              icon: Icons.input_rounded,
              namedLocation: context.namedLocation('inboundOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.tlsTricks.title,
              icon: Icons.content_cut_rounded,
              namedLocation: context.namedLocation('tlsTricks'),
            ),
            SettingsSection(
              title: t.pages.settings.warp.title,
              icon: Icons.cloud_rounded,
              namedLocation: context.namedLocation('warpOptions'),
            ),
            if (PlatformUtils.isIOS)
              Material(
                child: ListTile(
                  title: Text(t.pages.settings.resetTunnel),
                  leading: const Icon(Icons.autorenew_rounded),
                  onTap: () async => ref.read(resetTunnelNotifierProvider.notifier).run(),
                ),
              ),
            if (Breakpoint(context).isMobile()) ...[
              SettingsSection(
                title: t.pages.logs.title,
                icon: Icons.description_rounded,
                namedLocation: context.namedLocation('logs'),
              ),
              SettingsSection(
                title: t.pages.about.title,
                icon: Icons.info_rounded,
                namedLocation: context.namedLocation('about'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

void _showAddConfigSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_rounded),
            title: const Text('Сканировать QR-код'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.goNamed('connect');
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste_rounded),
            title: const Text('Из буфера обмена'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final data = await Clipboard.getData('text/plain');
              final url = data?.text?.trim() ?? '';
              if (url.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Буфер обмена пуст')),
                  );
                }
                return;
              }
              if (context.mounted) {
                ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: url);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Вставить вручную'),
            onTap: () {
              Navigator.of(ctx).pop();
              ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({super.key, required this.title, required this.icon, required this.namedLocation});

  final String title;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
