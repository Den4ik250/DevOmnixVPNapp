import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:devomnix/features/auth/data/telegram_link_payload.dart';
import 'package:devomnix/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ловит deeplink `devomnix://auth` из бота и проводит привязку аккаунта.
///
/// Кейсы, требующие вопроса пользователю, разруливаются здесь:
///   T3 — устройство привязано к другому Telegram → «Выйти и войти заново?»
///   T5 — номер в Telegram отличается от номера в аккаунте → «Обновить?»
///
/// Остальное бэкенд решает сам и молча (T1, T2, T4, T6).
class TelegramLinkWrapper extends HookConsumerWidget {
  const TelegramLinkWrapper({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      final links = AppLinks();

      Future<void> handle(Uri uri) async {
        final payload = TelegramLinkPayload.tryParse(uri);
        if (payload == null) return;   // не наш deeplink — не трогаем
        await _runLink(ref, payload);
      }

      // Холодный старт: приложение открыли самой ссылкой, поток её не отдаст.
      links.getInitialLink().then((uri) {
        if (uri != null) handle(uri);
      });

      final sub = links.uriLinkStream.listen(handle);
      return sub.cancel;
    }, const []);

    return child;
  }

  Future<void> _runLink(WidgetRef ref, TelegramLinkPayload payload) async {
    final notifier = ref.read(authNotifierProvider.notifier);
    var outcome = await notifier.linkTelegram(payload);

    // T3: устройство принадлежит другому Telegram
    if (outcome.needsForce) {
      final confirmed = await _ask(
        title: 'Аккаунт привязан к другому Telegram',
        message: outcome.conflictMessage ??
            'Это устройство привязано к другому Telegram-аккаунту.',
        confirmLabel: 'Выйти и войти заново',
      );
      if (confirmed != true) return;
      outcome = await notifier.linkTelegram(payload, force: true);
    }

    if (!outcome.isSuccess) {
      _toast(outcome.conflictMessage ?? 'Не удалось привязать аккаунт');
      return;
    }

    // T5: номер расходится
    final conflict = outcome.phoneConflict;
    if (conflict != null && conflict.canConfirm) {
      final confirmed = await _ask(
        title: 'Другой номер телефона',
        message: 'Номер в Telegram (${conflict.incoming}) отличается от номера '
            'в приложении (${conflict.current}). Обновить?',
        confirmLabel: 'Обновить',
      );
      if (confirmed == true) {
        outcome = await notifier.linkTelegram(payload, confirmPhone: true);
      }
    } else if (conflict != null && conflict.isTaken) {
      _toast('Номер ${conflict.incoming} уже привязан к другому аккаунту. '
          'Обратитесь в поддержку.');
      return;
    }

    final result = outcome.result;
    _toast(result != null && result.merged
        ? 'Аккаунт Telegram привязан, подписка синхронизирована'
        : 'Аккаунт Telegram привязан');
  }

  Future<bool?> _ask({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }
}
