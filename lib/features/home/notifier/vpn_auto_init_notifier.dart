import 'package:hiddify/features/backend/backend_service.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_mapper.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Silently fetches a VLESS config from the backend on first launch
/// (when no profile exists). Also handles server switching.
class VpnAutoInitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await _initIfNeeded();
  }

  Future<void> _initIfNeeded() async {
    try {
      final hasProfile = await ref.read(hasAnyProfileProvider.future);
      if (hasProfile) return;
      await _addProfileFromBackend();
    } catch (_) {
      // Silent fail — user may have no subscription or backend may be offline
    }
  }

  Future<bool> _addProfileFromBackend({int? serverId}) async {
    final vlessUrl = await ref.read(backendServiceProvider).fetchVlessConfig(serverId: serverId);
    final repo = await ref.read(profileRepositoryProvider.future);
    final result = await repo.addLocal(
      vlessUrl,
      userOverride: const UserOverride(name: 'DevOmnix VPN'),
    ).run();
    return result.isRight();
  }

  /// Switch to a different server: update profile content, reconnect if needed.
  Future<void> switchServer(int serverId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final vlessUrl = await ref.read(backendServiceProvider).fetchVlessConfig(serverId: serverId);
      final repo = await ref.read(profileRepositoryProvider.future);
      final dataSource = ref.read(profileDataSourceProvider);

      final existing = await dataSource.getByName('DevOmnix VPN');
      if (existing != null) {
        final entity = existing.toEntity();
        await repo.offlineUpdate(entity, vlessUrl).run();
        // Reconnect if the updated profile is currently active
        final active = ref.read(activeProfileProvider).valueOrNull;
        if (active != null && active.id == entity.id) {
          await ref.read(connectionNotifierProvider.notifier).reconnect(entity);
        }
      } else {
        await _addProfileFromBackend(serverId: serverId);
      }
    });
  }

  /// Re-fetch VLESS config from backend and update local profile.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _addProfileFromBackend());
  }
}

final vpnAutoInitProvider = AsyncNotifierProvider<VpnAutoInitNotifier, void>(
  VpnAutoInitNotifier.new,
);

/// Currently selected server ID (null = auto / first server).
final selectedServerIdProvider = StateProvider<int?>((ref) => null);

/// FutureProvider for the server list; auto-refreshes on mount.
final vpnServersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await ref.read(backendServiceProvider).fetchServers();
});
