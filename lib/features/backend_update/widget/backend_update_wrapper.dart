import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:devomnix/features/backend_update/model/backend_update_state.dart';
import 'package:devomnix/features/backend_update/notifier/backend_update_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class BackendUpdateWrapper extends HookConsumerWidget {
  const BackendUpdateWrapper({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future.microtask(() => ref.read(backendUpdateProvider.notifier).check());
      return null;
    }, const []);

    ref.listen<BackendUpdateState>(backendUpdateProvider, (prev, next) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      // Force update — non-dismissable dialog
      if (next.status == BackendUpdateStatus.forceUpdate &&
          prev?.status != BackendUpdateStatus.forceUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceUpdateDialog(ctx, next);
        });
      }

      // Soft update — banner at bottom
      if (next.status == BackendUpdateStatus.softUpdate &&
          prev?.status != BackendUpdateStatus.softUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSoftUpdateSnackbar(ctx, next);
        });
      }
    });

    return child;
  }
}

void _showSoftUpdateSnackbar(BuildContext context, BackendUpdateState state) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Доступно обновление ${state.latestVersion}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Скачать',
        onPressed: () {
          if (state.downloadUrl.isNotEmpty) {
            launchUrl(
              Uri.parse(state.downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      ),
    ),
  );
}

void _showForceUpdateDialog(BuildContext context, BackendUpdateState state) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Требуется обновление'),
        content: const Text(
          'Эта версия больше не поддерживается. Пожалуйста, обновите приложение.',
        ),
        actions: [
          FilledButton(
            onPressed: () => launchUrl(
              Uri.parse(state.downloadUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Обновить'),
          ),
        ],
      ),
    ),
  );
}
