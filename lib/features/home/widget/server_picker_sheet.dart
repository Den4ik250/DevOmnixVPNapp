import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:devomnix/features/home/notifier/vpn_auto_init_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Bottom sheet for selecting a VPN server.
class ServerPickerSheet extends ConsumerWidget {
  const ServerPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(vpnServersProvider);
    final selectedId = ref.watch(selectedServerIdProvider);
    final switching = ref.watch(vpnAutoInitProvider).isLoading;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.public_rounded),
                const Gap(8),
                Text('Выбрать сервер', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          serversAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Не удалось загрузить список серверов',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            data: (servers) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final s = servers[index];
                final id = s['id'] as int;
                final isSelected = selectedId == id || (selectedId == null && index == 0);
                final ping = s['ping_ms'] as int?;
                return ListTile(
                  leading: Text(
                    s['flag'] as String? ?? '🌐',
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(s['country'] as String? ?? s['name'] as String),
                  subtitle: Text(s['name'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PingBadge(ping),
                      const Gap(8),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      else
                        const Icon(Icons.circle_outlined, color: Colors.grey),
                    ],
                  ),
                  enabled: !switching,
                  onTap: isSelected
                      ? null
                      : () async {
                          ref.read(selectedServerIdProvider.notifier).state = id;
                          await ref.read(vpnAutoInitProvider.notifier).switchServer(id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PingBadge extends StatelessWidget {
  const _PingBadge(this.ping);
  final int? ping;

  @override
  Widget build(BuildContext context) {
    if (ping == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('—', style: TextStyle(color: Colors.red, fontSize: 12)),
      );
    }
    final color = ping! < 100 ? Colors.green : ping! < 250 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$ping ms', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void showServerPickerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const ServerPickerSheet(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );
}
