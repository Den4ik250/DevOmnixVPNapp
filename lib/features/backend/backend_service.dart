import 'package:hiddify/features/backend/backend_api_provider.dart';
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

  Future<List<Map<String, dynamic>>> fetchServers() async {
    final dio = _ref.read(backendDioProvider);
    final response = await dio.get('/vpn/servers');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
