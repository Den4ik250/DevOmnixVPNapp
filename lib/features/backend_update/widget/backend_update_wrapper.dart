import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/features/backend_update/model/backend_update_state.dart';
import 'package:hiddify/features/backend_update/notifier/backend_update_notifier.dart';
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
      if (next.status == BackendUpdateStatus.forceUpdate &&
          prev?.status != BackendUpdateStatus.forceUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            _showForceUpdateDialog(ctx, next);
          }
        });
      }
    });

    return child;
  }
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
