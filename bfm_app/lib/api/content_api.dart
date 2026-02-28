import 'package:bfm_app/api/api_client.dart';

/// Backend content endpoints (tips, events).
class ContentApi {
  ContentApi(this._client);
  final ApiClient _client;

  /// GET /tips -> list of tip objects.
  Future<List<Map<String, dynamic>>> tips() async {
    final response = await _client.dio.get('/tips');
    return _extractList(response.data);
  }

  /// GET /events -> list of event objects.
  Future<List<Map<String, dynamic>>> events() async {
    final response = await _client.dio.get('/events');
    return _extractList(response.data);
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['items'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
