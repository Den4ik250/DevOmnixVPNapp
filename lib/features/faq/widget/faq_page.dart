import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:url_launcher/url_launcher.dart';

const _faqs = [
  (
    q: 'Как подключиться к VPN?',
    a: 'После оформления подписки нажмите кнопку подключения на главном экране. '
        'Конфигурация загружается автоматически. Первое подключение может занять до 30 секунд.'
  ),
  (
    q: 'Сколько устройств можно подключить?',
    a: 'Индивидуальные тарифы (Стартовый, Стандарт, Премиум) — 1 устройство. '
        'Групповые тарифы (Группа Стандарт, Группа Премиум) — до 5 устройств одновременно.'
  ),
  (
    q: 'Как работают скидки при длительной подписке?',
    a: '1 месяц — без скидки\n3 месяца — −10%\n6 месяцев — −20%\n12 месяцев — −30%\n\n'
        'Итоговая сумма рассчитывается автоматически при выборе периода.'
  ),
  (
    q: 'Что такое реферальная программа?',
    a: 'Пригласите друга по своей реферальной ссылке. Когда он оформит подписку:\n'
        '• Стандарт: вы получите +50 ₽ на кошелёк, друг — скидку −30%\n'
        '• Премиум: вы получите +80 ₽ на кошелёк, друг — скидку −50%'
  ),
  (
    q: 'Как пополнить кошелёк?',
    a: 'Кошелёк пополняется автоматически через реферальную программу. '
        'Баланс кошелька автоматически списывается при следующей оплате подписки.'
  ),
  (
    q: 'Как отменить или приостановить подписку?',
    a: 'Подписка работает до истечения оплаченного периода без автопродления. '
        'Просто не оплачивайте следующий период, и доступ завершится автоматически.'
  ),
  (
    q: 'Что делать, если VPN не подключается?',
    a: '1. Проверьте интернет-соединение\n'
        '2. Нажмите «Переподключиться» на главном экране\n'
        '3. Попробуйте сбросить конфигурацию в настройках\n'
        '4. Если проблема не решена — напишите в поддержку через Telegram'
  ),
  (
    q: 'Какие способы оплаты доступны?',
    a: 'Принимаем оплату банковской картой (через Lava.ru) и криптовалютой USDT/TON (через CryptoBot в Telegram).'
  ),
  (
    q: 'Мои данные в безопасности?',
    a: 'Мы используем протокол VLESS с шифрованием TLS/Reality. '
        'Мы не храним логи трафика и не передаём ваши данные третьим лицам. '
        'Подробнее — в Политике конфиденциальности.'
  ),
];

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Частые вопросы'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: _faqs.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, i) {
                final faq = _faqs[i];
                final isOpen = _expanded == i;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _expanded = isOpen ? null : i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq.q,
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              AnimatedRotation(
                                turns: isOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.keyboard_arrow_down_rounded),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: isOpen
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Text(
                                    faq.a,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.6,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (50 * i).ms).slideY(begin: .05, curve: Curves.easeOut);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: _SupportCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: theme.colorScheme.onPrimaryContainer),
                const Gap(8),
                Text(
                  'Поддержка',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              'Не нашли ответ? Напишите нам в Telegram — ответим быстро.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(Constants.telegramChannelUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.telegram, size: 18),
              label: const Text('Написать в Telegram'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                side: BorderSide(color: theme.colorScheme.onPrimaryContainer.withOpacity(.5)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
