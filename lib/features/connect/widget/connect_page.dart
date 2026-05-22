import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/backend/backend_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ConnectPage extends HookConsumerWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Подключение'),
          leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.goNamed('home')),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bolt_rounded), text: 'Быстро'),
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'QR-код'),
              Tab(icon: Icon(Icons.edit_rounded), text: 'Вручную'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FastConnectTab(),
            _QrConnectTab(),
            _ManualConnectTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Fast Connect ────────────────────────────────────────────────────────────

class _FastConnectTab extends HookConsumerWidget {
  const _FastConnectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 80, color: theme.colorScheme.primary)
                .animate()
                .scale(begin: const Offset(.5, .5))
                .fadeIn(),
            const Gap(24),
            Text(
              'Автоподключение',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              'Получает лучший VLESS-конфиг с нашего сервера и подключается одним нажатием.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Gap(40),
            FilledButton.icon(
              onPressed: isLoading.value
                  ? null
                  : () async {
                      isLoading.value = true;
                      try {
                        final vlessUrl =
                            await ref.read(backendServiceProvider).fetchVlessConfig();
                        if (!context.mounted) return;
                        ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: vlessUrl);
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка: $e'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      } finally {
                        isLoading.value = false;
                      }
                    },
              icon: isLoading.value
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded),
              label: Text(isLoading.value ? 'Подключение...' : 'Подключиться быстро'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── QR Connect ──────────────────────────────────────────────────────────────

class _QrConnectTab extends HookConsumerWidget {
  const _QrConnectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useMemoized(
      () => MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
    );
    useEffect(() => controller.dispose, [controller]);
    final scanned = useState(false);

    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (scanned.value) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null || raw.isEmpty) return;
              scanned.value = true;
              controller.stop();
              ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: raw);
              Navigator.of(context).pop();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Наведите камеру на QR-код с VLESS-конфигом',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ─── Manual Connect ───────────────────────────────────────────────────────────

class _ManualConnectTab extends HookConsumerWidget {
  const _ManualConnectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Вставьте VLESS-конфиг', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          TextField(
            controller: controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'vless://...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            keyboardType: TextInputType.multiline,
          ),
          const Gap(8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) controller.text = data!.text!;
                },
                icon: const Icon(Icons.paste_rounded),
                label: const Text('Вставить'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => controller.clear(),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Очистить'),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: url);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Применить конфиг'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
