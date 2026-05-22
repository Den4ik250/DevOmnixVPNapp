import 'package:hiddify/features/per_app_proxy/model/app_package_info.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:installed_apps/index.dart';

/// Loads user-facing installed apps (hide system, with icons) once and keeps them cached.
final installedUserAppsProvider = FutureProvider<Map<String, AppPackageInfo>>((ref) async {
  if (!PlatformUtils.isAndroid) return {};
  final raw = await InstalledApps.getInstalledApps(true, true);
  return {
    for (final app in raw)
      app.packageName: AppPackageInfo(
        packageName: app.packageName,
        name: app.name,
        icon: app.icon,
      ),
  };
});
