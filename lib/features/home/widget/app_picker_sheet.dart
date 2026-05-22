import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/home/notifier/installed_apps_provider.dart';
import 'package:hiddify/features/per_app_proxy/data/app_proxy_data_source.dart';
import 'package:hiddify/features/per_app_proxy/data/selected_data_provider.dart';
import 'package:hiddify/features/per_app_proxy/model/app_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Bottom-sheet app picker for the split-tunnel (proxy) mode.
/// Shows all installed user apps that are not yet in the proxy list.
/// Tapping an app immediately adds it; the row disappears from the list.
class AppPickerSheet extends HookConsumerWidget {
  const AppPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchQuery = useState('');

    final appsAsync = ref.watch(installedUserAppsProvider);
    final selectedPkgs = ref.watch(Preferences.includeApps).toSet();

    // Build the filtered, sorted list of apps that aren't yet in the proxy list
    final List<AppPackageInfo>? filteredApps = appsAsync.when(
      data: (map) {
        final available = map.values
            .where((app) => !selectedPkgs.contains(app.packageName))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (searchQuery.value.isEmpty) return available;
        final q = searchQuery.value.toLowerCase();
        return available.where((app) => app.name.toLowerCase().contains(q)).toList();
      },
      loading: () => null,
      error: (_, __) => <AppPackageInfo>[],
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Выберите приложения',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Закрыть',
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => searchQuery.value = v,
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: filteredApps == null
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            searchQuery.value.isEmpty
                                ? Icons.check_circle_outline_rounded
                                : Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const Gap(12),
                          Text(
                            searchQuery.value.isEmpty
                                ? 'Все приложения уже добавлены'
                                : 'Ничего не найдено',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: filteredApps.length,
                    itemBuilder: (_, i) {
                      final app = filteredApps[i];
                      return ListTile(
                        leading: app.icon != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  app.icon!,
                                  width: 42,
                                  height: 42,
                                  cacheWidth: 42,
                                  cacheHeight: 42,
                                ),
                              )
                            : Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                        title: Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        onTap: () => ref.read(appProxyDataSourceProvider).updatePkg(
                          pkg: app.packageName,
                          mode: AppProxyMode.include,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
