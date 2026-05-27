import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _PlanPricing {
  const _PlanPricing({
    required this.months,
    required this.finalPrice,
    required this.fullPrice,
    required this.discountPct,
  });
  final int months;
  final double finalPrice;
  final double fullPrice;
  final int discountPct;
}

class _Plan {
  const _Plan({
    required this.key,
    required this.name,
    required this.priceMonthly,
    required this.gbLimit,
    required this.devices,
    required this.isPromo,
    this.promoDays,
    this.once = false,
    required this.pricing,
  });
  final String key;
  final String name;
  final double priceMonthly;
  final int? gbLimit;
  final int devices;
  final bool isPromo;
  final int? promoDays;
  final bool once;
  final List<_PlanPricing> pricing;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _plansProvider = FutureProvider<List<_Plan>>((ref) async {
  final dio = ref.watch(backendDioProvider);
  final response = await dio.get('/subscriptions/plans');
  final items = response.data as List<dynamic>;
  return items.map((raw) {
    final map = raw as Map<String, dynamic>;
    final pricingRaw = map['pricing'] as Map<String, dynamic>;
    final pricing = <_PlanPricing>[];
    pricingRaw.forEach((key, value) {
      final months = int.parse(key);
      if (value is Map<String, dynamic>) {
        pricing.add(_PlanPricing(
          months: months,
          finalPrice: (value['final'] as num).toDouble(),
          fullPrice: (value['full'] as num).toDouble(),
          discountPct: value['discount_pct'] as int,
        ));
      } else {
        pricing.add(_PlanPricing(
          months: months,
          finalPrice: (value as num).toDouble(),
          fullPrice: (value).toDouble(),
          discountPct: 0,
        ));
      }
    });
    pricing.sort((a, b) => a.months.compareTo(b.months));
    return _Plan(
      key: map['key'] as String,
      name: map['name'] as String,
      priceMonthly: (map['price_monthly'] as num).toDouble(),
      gbLimit: map['gb_limit'] as int?,
      devices: map['devices'] as int,
      isPromo: map['is_promo'] as bool,
      promoDays: map['promo_days'] as int?,
      once: map['once'] as bool? ?? false,
      pricing: pricing,
    );
  }).toList();
});

// ── Page ─────────────────────────────────────────────────────────────────────

class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage> {
  final Map<String, int> _selectedMonths = {};
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(_plansProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тарифы'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          plansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const Gap(16),
                  Text('Не удалось загрузить тарифы', style: Theme.of(context).textTheme.titleMedium),
                  const Gap(8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(_plansProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
            data: (plans) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) {
                return _PlanCard(
                  plan: plans[i],
                  selectedMonths: _selectedMonths[plans[i].key] ?? 1,
                  onMonthsChanged: (m) => setState(() => _selectedMonths[plans[i].key] = m),
                  onBuy: (plan, months) => _handleBuy(plan, months),
                ).animate().fadeIn(delay: (80 * i).ms).slideY(begin: .1, curve: Curves.easeOut);
              },
            ),
          ),
          if (_paying)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBuy(_Plan plan, int months) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final dio = ref.read(backendDioProvider);
      final resp = await dio.post('/payments/create', data: {
        'plan': plan.key,
        'months': months,
        'provider': 'lava',
      });
      final data = resp.data as Map<String, dynamic>;

      if (!mounted) return;
      if (data['status'] == 'activated') {
        // Wallet covered full price — subscription is active now
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Подписка активирована'),
            content: Text('Тариф «${plan.name}» активен. Подключитесь через вкладку «Профили».'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отлично'))],
          ),
        );
      } else if (data['pay_url'] != null) {
        final uri = Uri.parse(data['pay_url'] as String);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _extractError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String _extractError(Object e) {
    try {
      // DioException has response.data
      final data = (e as dynamic).response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {}
    return 'Ошибка соединения с сервером';
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selectedMonths,
    required this.onMonthsChanged,
    required this.onBuy,
  });

  final _Plan plan;
  final int selectedMonths;
  final ValueChanged<int> onMonthsChanged;
  final void Function(_Plan plan, int months) onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = plan.key.contains('premium');
    final isGroup = plan.key.startsWith('group');
    final color = isPremium
        ? theme.colorScheme.tertiary
        : isGroup
            ? theme.colorScheme.secondary
            : theme.colorScheme.primary;

    final selectedPricing = plan.pricing.firstWhere(
      (p) => p.months == selectedMonths,
      orElse: () => plan.pricing.first,
    );

    return Card(
      elevation: isPremium ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isPremium
            ? BorderSide(color: color.withOpacity(.6), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.name,
                    style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (isPremium)
                  Icon(Icons.star_rounded, color: color, size: 20),
              ],
            ),
            const Gap(12),
            Row(
              children: [
                _InfoChip(Icons.devices, '${plan.devices} устр.'),
                const Gap(8),
                _InfoChip(
                  Icons.data_usage,
                  plan.gbLimit == null ? '∞ трафик' : '${plan.gbLimit} ГБ',
                ),
                if (plan.isPromo) ...[
                  const Gap(8),
                  _InfoChip(Icons.calendar_today, '${plan.promoDays} дней', color: Colors.green),
                ],
              ],
            ),
            if (!plan.isPromo) ...[
              const Gap(16),
              _DurationSelector(
                pricing: plan.pricing,
                selected: selectedMonths,
                onSelected: onMonthsChanged,
                color: color,
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedPricing.discountPct > 0)
                        Text(
                          '${selectedPricing.fullPrice.toStringAsFixed(0)} ₽',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${selectedPricing.finalPrice.toStringAsFixed(0)} ₽',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${_monthLabel(selectedMonths)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: () => onBuy(plan, selectedMonths),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Купить'),
                  ),
                ],
              ),
            ] else ...[
              const Gap(16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onBuy(plan, 0),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Активировать бесплатно'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _monthLabel(int months) {
    if (months == 1) return '1 месяц';
    if (months == 3) return '3 месяца';
    if (months == 6) return '6 месяцев';
    return '12 месяцев';
  }

}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const Gap(4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: c)),
      ],
    );
  }
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({
    required this.pricing,
    required this.selected,
    required this.onSelected,
    required this.color,
  });

  final List<_PlanPricing> pricing;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      children: pricing.map((p) {
        final isSelected = p.months == selected;
        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_label(p.months)),
              if (p.discountPct > 0)
                Text(
                  '−${p.discountPct}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? theme.colorScheme.onSecondaryContainer : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          selected: isSelected,
          selectedColor: color.withOpacity(.2),
          onSelected: (_) => onSelected(p.months),
          side: isSelected ? BorderSide(color: color) : null,
        );
      }).toList(),
    );
  }

  String _label(int months) {
    if (months == 1) return '1 мес';
    if (months == 3) return '3 мес';
    if (months == 6) return '6 мес';
    return '12 мес';
  }
}
