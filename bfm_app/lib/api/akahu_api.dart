import 'package:dio/dio.dart';

import 'package:bfm_app/api/api_client.dart';

/// Backend-proxied Akahu endpoints.
///
/// These go through the Moni backend (not directly to api.akahu.io).
/// The backend handles Akahu credentials on behalf of the user.
class AkahuApi {
  AkahuApi(this._client);
  final ApiClient _client;

  /// GET /akahu/connect -> returns a URL to open in a browser for OAuth.
  ///
  /// Handles three backend response styles:
  ///   1. 302 redirect → capture the Location header
  ///   2. JSON body with a url/redirect_url/data field
  ///   3. Plain string URL
  Future<Uri> connectUrl() async {
    final response = await _client.dio.get(
      '/akahu/connect',
      options: Options(
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    // 302/301 redirect: pull URL from Location header
    final statusCode = response.statusCode ?? 200;
    if (statusCode >= 300 && statusCode < 400) {
      final location = response.headers.value('location');
      if (location != null && location.isNotEmpty) return Uri.parse(location);
    }

    final data = response.data;
    String url;
    if (data is String) {
      url = data.trim();
    } else if (data is Map<String, dynamic>) {
      url = (data['url'] ?? data['redirect_url'] ?? data['data'] ?? '')
          .toString()
          .trim();
    } else {
      throw Exception('Unexpected connect response: $data');
    }
    if (url.isEmpty) throw Exception('Empty connect URL from backend');
    return Uri.parse(url);
  }

  /// GET /akahu/accounts -> list of account maps.
  Future<List<Map<String, dynamic>>> accounts() async {
    final response = await _client.dio.get('/akahu/accounts');
    return _extractList(response.data);
  }

  /// GET /akahu/transactions -> list of transaction maps.
  ///
  /// Paginates automatically if the backend returns Laravel-style pagination
  /// (`current_page`, `last_page`) so we get ALL transactions, not just one
  /// page. Falls back to a single-request fetch if no pagination metadata.
  Future<List<Map<String, dynamic>>> transactions() async {
    final all = <Map<String, dynamic>>[];
    int page = 1;

    while (true) {
      final response = await _client.dio.get(
        '/akahu/transactions',
        queryParameters: {'page': page, 'per_page': 500},
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      final data = response.data;
      final items = _extractList(data);
      all.addAll(items);

      // Laravel pagination: { data: [...], current_page: 1, last_page: 3 }
      if (data is Map<String, dynamic>) {
        final currentPage = data['current_page'] as int?;
        final lastPage = data['last_page'] as int?;
        if (currentPage != null && lastPage != null && currentPage < lastPage) {
          page++;
          continue;
        }
      }
      break;
    }

    return all;
  }

  /// DELETE /akahu/revoke -> revoke the Akahu session on the backend.
  Future<void> revoke() async {
    await _client.dio.delete('/akahu/revoke');
  }

  /// Handles both `[...]` and `{ data: [...] }` shapes.
  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ??
          data['items'] ??
          data['accounts'] ??
          data['transactions'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
