import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _WalletData {
  const _WalletData({required this.balance, required this.transactions});
  final double balance;
  final List<_Transaction> transactions;
}

class _Transaction {
  const _Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });
  final int id;
  final String type;
  final double amount;
  final String? description;
  final DateTime createdAt;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _walletProvider = FutureProvider<_WalletData>((ref) async {
  final dio = ref.watch(backendDioProvider);
  final response = await dio.get('/wallet/');
  final data = response.data as Map<String, dynamic>;
  final txns = (data['transactions'] as List<dynamic>).map((t) {
    final m = t as Map<String, dynamic>;
    return _Transaction(
      id: m['id'] as int,
      type: m['type'] as String,
      amount: (m['amount'] as num).toDouble(),
      description: m['description'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
  return _WalletData(
    balance: (data['balance'] as num).toDouble(),
    transactions: txns,
  );
});

// ── Page ─────────────────────────────────────────────────────────────────────

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(_walletProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кошелёк'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_walletProvider),
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const Gap(16),
              Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
              const Gap(8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_walletProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (wallet) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _BalanceCard(balance: wallet.balance).animate().fadeIn(duration: 400.ms),
            ),
            if (wallet.transactions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const Gap(12),
                      Text(
                        'История операций пуста',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('История операций', style: theme.textTheme.titleSmall),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: wallet.transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    return _TransactionTile(txn: wallet.transactions[i])
                        .animate()
                        .fadeIn(delay: (40 * i).ms);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Баланс',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const Gap(8),
          Text(
            '${balance.toStringAsFixed(2)} ₽',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(4),
          Text(
            'Пополняется автоматически при реферальных бонусах',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final _Transaction txn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = txn.amount > 0;
    final color = isCredit ? Colors.green : theme.colorScheme.error;
    final icon = isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        txn.description ?? _typeLabel(txn.type),
        style: theme.textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        fmt.format(txn.createdAt.toLocal()),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        '${isCredit ? '+' : ''}${txn.amount.toStringAsFixed(2)} ₽',
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'referral_bonus':
        return 'Реферальный бонус';
      case 'payment':
        return 'Оплата';
      case 'admin_credit':
        return 'Начисление от администратора';
      case 'wallet_deduction':
        return 'Списание за покупку';
      default:
        return type;
    }
  }
}
