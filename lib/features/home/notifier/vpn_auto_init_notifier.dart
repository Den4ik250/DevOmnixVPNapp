import 'package:devomnix/core/preferences/general_preferences.dart';
import 'package:devomnix/features/auth/notifier/subscription_guard.dart';
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
// Единый источник правды для экранов. Запрос принадлежит [SubscriptionGuard]:
// у него кеш на 5 минут и склейка параллельных вызовов, поэтому три экрана,
// открытые подряд, дают один запрос, а не три.
//
// 🔴 Ошибку больше НЕ подменяем на `false`. Раньше здесь стоял
// `catch (_) { return false; }`, и любой обрыв связи экран показывал как
// «нет активной подписки» — включая случай с активным промокодом VIP.
// Теперь отказ уходит в AsyncError, и экран печатает настоящую причину.
/// Сколько экран ждёт ответа, прежде чем показать причину вместо спиннера.
/// Сам запрос при этом не отменяется — досчитается и разбудит экран через
/// [accountRevisionProvider].
const _screenTimeout = Duration(seconds: 12);

final subscriptionStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Токен может приехать позже первой отрисовки (вход на старте повторяет
  // попытку). Тогда этот провайдер обязан перезапроситься сам, иначе экран
  // так и останется с ошибкой до перехода туда-обратно.
  ref.watch(Preferences.jwtToken);
  ref.watch(accountRevisionProvider);
  final snapshot = await ref
      .read(subscriptionGuardProvider.notifier)
      .fetchMe(timeout: _screenTimeout);
  return snapshot.hasActiveSub;
});

/// Полный ответ `/auth/me` для экранов Профиля и «Мой аккаунт».
final accountInfoProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(Preferences.jwtToken);
  ref.watch(accountRevisionProvider);
  final snapshot = await ref
      .read(subscriptionGuardProvider.notifier)
      .fetchMe(timeout: _screenTimeout);
  return snapshot.me;
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

      // Точка 1 из трёх: проверка подписки при запуске приложения.
      // Идёт через guard, а не через subscriptionStatusProvider — заодно
      // поднимает часовой опрос и общий кеш на все точки проверки.
      final check =
          await ref.read(subscriptionGuardProvider.notifier).checkOnStartup();
      // Конфиг качать имеет смысл только при подтверждённой подписке.
      // При `unknown` сети всё равно нет — запрос за конфигом упадёт следом.
      if (check != SubscriptionCheck.active) return;

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

    final existing = await dataSource.getByName(kAutoProfileName);
    final String profileId;
    if (existing != null) {
      final entity = existing.toEntity();
      await repo.offlineUpdate(entity, vlessUrl).run();
      profileId = entity.id;
    } else {
      final result = await repo.addLocal(
        vlessUrl,
        userOverride: const UserOverride(name: kAutoProfileName),
      ).run();
      if (result.isLeft()) return false;
      final added = await dataSource.getByName(kAutoProfileName);
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

      final existing = await dataSource.getByName(kAutoProfileName);
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

      final existing = await dataSource.getByName(kAutoProfileName);
      final String profileId;
      if (existing != null) {
        final entity = existing.toEntity();
        await repo.offlineUpdate(entity, vlessUrl).run();
        profileId = entity.id;
      } else {
        await repo.addLocal(
          vlessUrl,
          userOverride: const UserOverride(name: kAutoProfileName),
        ).run();
        final added = await dataSource.getByName(kAutoProfileName);
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

  /// Пересоздаёт конфиг на бэкенде (POST /vpn/reset) и заменяет ТОЛЬКО
  /// авто-профиль (по [kAutoProfileName]), не трогая ручные серверы.
  /// Возвращает новый vless_url. Переподключается сам, если VPN активен.
  Future<String> resetAndReconnect() async {
    final vlessUrl = await ref.read(backendServiceProvider).resetVlessConfig();
    final repo = await ref.read(profileRepositoryProvider.future);
    final dataSource = ref.read(profileDataSourceProvider);

    final existing = await dataSource.getByName(kAutoProfileName);
    final ProfileEntity profile;
    if (existing != null) {
      // Обновляем содержимое существующего авто-профиля (id не меняется).
      final entity = existing.toEntity();
      await repo.offlineUpdate(entity, vlessUrl).run();
      profile = entity;
    } else {
      // Авто-профиля ещё нет — создаём с тем же стабильным именем.
      await repo.addLocal(
        vlessUrl,
        userOverride: const UserOverride(name: kAutoProfileName),
      ).run();
      final added = await dataSource.getByName(kAutoProfileName);
      if (added == null) throw Exception('Не удалось создать авто-профиль после reset');
      profile = added.toEntity();
    }

    // Принудительно делаем авто-профиль активным (не зависим от _initIfNeeded).
    await repo.setAsActive(profile.id).run();

    // Слушатель activeProfileProvider переподключает только при СМЕНЕ id.
    // При offlineUpdate id тот же → reconnect делаем явно. Внутри reconnect
    // есть guard: срабатывает только если VPN сейчас Connected.
    await ref.read(connectionNotifierProvider.notifier).reconnect(profile);
    return vlessUrl;
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
