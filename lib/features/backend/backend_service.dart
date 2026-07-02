import 'package:devomnix/features/backend/backend_api_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService(ref);
});

class BackendService {
  BackendService(this._ref);

  final Ref _ref;

  Future<String> fetchVlessConfig({int? serverId}) async {
    final dio = _ref.read(backendDioProvider);
    final response = await dio.get(
      '/vpn/config',
      queryParameters: serverId != null ? {'server_id': serverId} : null,
    );
    final data = response.data as Map<String, dynamic>;
    final vlessUrl = data['vless_url'] as String?;
    if (vlessUrl == null || vlessUrl.isEmpty) {
      throw Exception('No VLESS config returned from backend');
    }
    return vlessUrl;
  }

  /// Пересоздаёт клиента в 3X-UI (POST /vpn/reset) и возвращает свежий vless_url.
  Future<String> resetVlessConfig() async {
    final dio = _ref.read(backendDioProvider);
    final response = await dio.post('/vpn/reset');
    final data = response.data as Map<String, dynamic>;
    final vlessUrl = data['vless_url'] as String?;
    if (vlessUrl == null || vlessUrl.isEmpty) {
      throw Exception('No VLESS config returned from /vpn/reset');
    }
    return vlessUrl;
  }

  Future<List<Map<String, dynamic>>> fetchServers() async {
    final dio = _ref.read(backendDioProvider);
    final response = await dio.get('/vpn/servers');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
