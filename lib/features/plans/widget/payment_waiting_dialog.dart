import 'dart:async';

import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ждёт подтверждения оплаты, опрашивая бэкенд.
///
/// Поллинг здесь — не индикатор, а механизм зачисления: пока у бэкенда нет
/// домена с TLS, касса не может прислать вебхук, и `GET /payments/{id}/status`
/// сам ходит в Platega за статусом. Как появится домен, поллинг останется
/// только индикатором, менять ничего не придётся.
class PaymentWaitingDialog extends ConsumerStatefulWidget {
  const PaymentWaitingDialog({required this.paymentId, super.key});

  final int paymentId;

  @override
  ConsumerState<PaymentWaitingDialog> createState() => _PaymentWaitingDialogState();
}

class _PaymentWaitingDialogState extends ConsumerState<PaymentWaitingDialog> {
  static const _interval = Duration(seconds: 4);
  static const _timeout = Duration(minutes: 15);

  Timer? _timer;
  DateTime? _startedAt;
  String? _error;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(_interval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted) return;

    // Счета у касс живут ограниченное время; висеть здесь вечно бессмысленно.
    if (DateTime.now().difference(_startedAt!) > _timeout) {
      _timer?.cancel();
      if (mounted) setState(() => _expired = true);
      return;
    }

    try {
      final dio = ref.read(backendDioProvider);
      final r = await dio.get('/payments/${widget.paymentId}/status');
      final status = (r.data as Map<String, dynamic>)['status']?.toString();

      if (status == 'paid') {
        _timer?.cancel();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (status == 'failed') {
        _timer?.cancel();
        if (mounted) setState(() => _error = 'Оплата не прошла');
      }
    } catch (_) {
      // Обрыв связи на одном опросе — не повод сдаваться, ждём следующего.
      // Реальную ошибку покажет либо статус failed, либо таймаут.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_error != null || _expired) {
      return AlertDialog(
        title: Text(_error ?? 'Оплата не подтверждена'),
        content: Text(
          _error != null
              ? 'Деньги не списаны. Попробуйте ещё раз или выберите другой способ.'
              : 'Мы не получили подтверждения от платёжной системы.\n\n'
                  'Если деньги списались — подписка включится автоматически '
                  'в течение нескольких минут. Если этого не произошло, '
                  'напишите в поддержку.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(8),
          const CircularProgressIndicator(),
          const Gap(20),
          Text('Ожидаем оплату', style: theme.textTheme.titleMedium),
          const Gap(8),
          Text(
            'Завершите оплату в открывшемся окне. '
            'Подписка включится автоматически.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
