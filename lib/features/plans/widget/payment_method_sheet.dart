import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Способы оплаты. Значения `apiValue` совпадают с `PaymentProvider`
/// на бэкенде — расходиться им нельзя.
enum PaymentMethod {
  platega(
    apiValue: 'platega',
    title: 'Картой или через СБП',
    subtitle: 'Карта РФ, СБП, криптовалюта',
    icon: Icons.credit_card,
  ),
  stars(
    apiValue: 'stars',
    title: 'Telegram Stars',
    subtitle: 'Оплата в боте, без карты',
    icon: Icons.star_rounded,
  ),
  wallet(
    apiValue: 'wallet',
    title: 'С баланса',
    subtitle: 'Бонусный счёт и реферальные начисления',
    icon: Icons.account_balance_wallet_outlined,
  );

  const PaymentMethod({
    required this.apiValue,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String apiValue;
  final String title;
  final String subtitle;
  final IconData icon;
}

class PaymentMethodSheet extends StatelessWidget {
  const PaymentMethodSheet({
    required this.planName,
    required this.months,
    super.key,
  });

  final String planName;
  final int months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Способ оплаты', style: theme.textTheme.titleLarge),
            const Gap(4),
            Text(
              '$planName · $months мес',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Gap(16),
            for (final method in PaymentMethod.values)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(method.icon, color: theme.colorScheme.primary),
                  title: Text(method.title),
                  subtitle: Text(method.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, method),
                ),
              ),
            const Gap(8),
            Text(
              'Оплачивая, вы принимаете условия сервиса. '
              'Возврат — по обращению в поддержку в течение 24 часов.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
