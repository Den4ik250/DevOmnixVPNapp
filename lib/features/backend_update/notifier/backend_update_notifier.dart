import 'package:dio/dio.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/backend_update/model/backend_update_state.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

final backendUpdateProvider =
    StateNotifierProvider<BackendUpdateNotifier, BackendUpdateState>(
  (ref) => BackendUpdateNotifier(),
);

class BackendUpdateNotifier extends StateNotifier<BackendUpdateState> {
  BackendUpdateNotifier() : super(const BackendUpdateState());

  Future<void> check() async {
    state = const BackendUpdateState(status: BackendUpdateStatus.checking);
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: Constants.backendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await dio.get('/version');
      final data = response.data as Map<String, dynamic>;

      final latestVersion = data['latest_version'] as String;
      final forceUpdate = data['force_update'] as bool? ?? false;
      final whatsNew = data['whats_new'] as String? ?? '';
      final downloadUrl = data['download_url'] as String? ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final current = Version.parse(packageInfo.version);
      final latest = Version.parse(latestVersion);

      if (latest <= current) {
        state = const BackendUpdateState(status: BackendUpdateStatus.upToDate);
        return;
      }

      state = BackendUpdateState(
        status: forceUpdate
            ? BackendUpdateStatus.forceUpdate
            : BackendUpdateStatus.softUpdate,
        latestVersion: latestVersion,
        whatsNew: whatsNew,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      state = const BackendUpdateState(status: BackendUpdateStatus.error);
    }
  }
}
