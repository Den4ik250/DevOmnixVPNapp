import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:devomnix/features/backend/backend_service.dart';
import 'package:devomnix/features/connection/notifier/connection_notifier.dart';
import 'package:devomnix/features/profile/data/profile_data_mapper.dart';
import 'package:devomnix/features/profile/data/profile_data_providers.dart';
import 'package:devomnix/features/profile/model/profile_entity.dart';
import 'package:devomnix/features/profile/notifier/active_profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Стабильное имя авто-профиля (от бэкенда) — отличает его от ручных серверов.
const kAutoProfileName = 'DevOmnix VPN';

// ─── Централизованный статус подписки ────────────────────────────────────────
// Единый источник правды: оба экрана (кнопка и профиль) используют этот provider.
final subscriptionStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final dio = ref.watch(backendDioProvider);
    final r = await dio.get('/auth/me');
    final data = Map<String, dynamic>.from(r.data as Map);
    return data['has_active_sub'] == true;
  } catch (_) {
    return false;
  }
});

/// Silently fetches a VLESS config from the backend on first launch
/// (when no profile exists). Also handles server switching.
class VpnAutoInitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await _initIfNeeded();
  }

  Future<void> _initIfNeeded() async {
    try {
      final activeProfile = await ref.read(activeProfileProvider.future);
      if (activeProfile != null) return; // уже есть активный профиль

      // Проверяем бэкенд — есть ли активная подписка
      final hasActiveSub = await ref.read(subscriptionStatusProvider.future);
      if (!hasActiveSub) return; // нет подписки — молча выходим

      await _addAndActivateProfileFromBackend();
    } catch (_) {
      // Silent fail — backend may be offline
    }
  }

  /// Добавляет профиль и сразу делает его активным.
  Future<bool> _addAndActivateProfileFromBackend({int? serverId}) async {
    final vlessUrl = await ref.read(backendServiceProvider).fetchVlessConfig(serverId: serverId);
    final repo = await ref.read(profileRepositoryProvider.future);
    final dataSource = ref.read(profileDataSourceProvider);

    final existing = await dataSource.getByName('DevOmnix VPN');
    final String profileId;
    if (existing != null) {
      final entity = existing.toEntity();
      await repo.offlineUpdate(entity, vlessUrl).run();
      profileId = entity.id;
    } else {
      final result = await repo.addLocal(
        vlessUrl,
        userOverride: const UserOverride(name: 'DevOmnix VPN'),
      ).run();
      if (result.isLeft()) return false;
      final added = await dataSource.getByName('DevOmnix VPN');
      if (added == null) return false;
      profileId = added.toEntity().id;
    }

    await repo.setAsActive(profileId).run();
    return true;
  }

  // Оставляем для обратной совместимости
  Future<bool> _addProfileFromBackend({int? serverId}) =>
      _addAndActivateProfileFromBackend(serverId: serverId);

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

  /// Activate subscription: fetch config, set profile active, connect VPN.
  /// Called after promo code or first subscription purchase.
  Future<void> activateAndConnect() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final vlessUrl = await ref.read(backendServiceProvider).fetchVlessConfig(serverId: 1);
      final repo = await ref.read(profileRepositoryProvider.future);
      final dataSource = ref.read(profileDataSourceProvider);

      final existing = await dataSource.getByName('DevOmnix VPN');
      final String profileId;
      if (existing != null) {
        final entity = existing.toEntity();
        await repo.offlineUpdate(entity, vlessUrl).run();
        profileId = entity.id;
      } else {
        await repo.addLocal(
          vlessUrl,
          userOverride: const UserOverride(name: 'DevOmnix VPN'),
        ).run();
        final added = await dataSource.getByName('DevOmnix VPN');
        if (added == null) return;
        profileId = added.toEntity().id;
      }

      await repo.setAsActive(profileId).run();
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
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
