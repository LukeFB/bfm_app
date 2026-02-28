/// ---------------------------------------------------------------------------
/// File: lib/services/akahu_service.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `transaction_sync_service.dart` when pulling new bank data.
///
/// Purpose:
///   - HTTP client for Akahu API endpoints (transactions, pending, refresh).
///
/// Inputs:
///   - App token (`X-Akahu-Id`) and user Bearer token.
///
/// Outputs:
///   - Parsed JSON payloads from Akahu API.
/// ---------------------------------------------------------------------------
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

/// Wraps direct Akahu HTTP calls behind static helpers.
///
/// TODO: This service calls api.akahu.io directly using raw tokens. For
/// production, prefer the backend-proxied AkahuApi (lib/api/akahu_api.dart)
/// which goes through the Moni backend. Keep this for dev/test with manual
/// token entry.
class AkahuService {
  static Map<String, String> _headers(String appToken, String userToken) => {
        "X-Akahu-Id": appToken,
        "Authorization": "Bearer $userToken",
      };

  /// Fetches settled transactions from Akahu API using cursor pagination.
  /// Optional [start]/[end] map to Akahu's query params.
  static Future<List<Map<String, dynamic>>> fetchTransactions(
    String appToken,
    String userToken, {
    DateTime? start,
    DateTime? end,
  }) async {
    return _fetchPaginated(
      appToken,
      userToken,
      '/v1/transactions',
      start: start,
      end: end,
    );
  }

  /// Fetches pending transactions from Akahu API.
  /// Pending transactions are still being processed and may change.
  /// These often contain the most recent transactions that haven't settled yet.
  static Future<List<Map<String, dynamic>>> fetchPendingTransactions(
    String appToken,
    String userToken,
  ) async {
    // Pending endpoint doesn't support date filtering per Akahu docs
    return _fetchPaginated(appToken, userToken, '/v1/transactions/pending');
  }

  /// Fetches all connected accounts for the user.
  /// Returns account IDs needed for triggering refreshes.
  static Future<List<Map<String, dynamic>>> fetchAccounts(
    String appToken,
    String userToken,
  ) async {
    return _fetchPaginated(appToken, userToken, '/v1/accounts');
  }

  /// Triggers a manual data refresh for all user accounts.
  /// Akahu caches data and refreshes it periodically (default 24h).
  /// This requests an immediate refresh to get the latest transactions.
  ///
  /// Note: Personal apps have a 1-hour cooldown, full apps have 15-min cooldown.
  /// Returns true if refresh was triggered, false if rate limited or failed.
  static Future<bool> triggerRefresh(
    String appToken,
    String userToken,
  ) async {
    final headers = _headers(appToken, userToken);

    try {
      // POST to /v1/refresh triggers refresh for all user's connected accounts
      final uri = Uri.https('api.akahu.io', '/v1/refresh');
      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 202) {
        log('Akahu refresh triggered successfully');
        return true;
      } else if (response.statusCode == 429) {
        // Rate limited - cooldown period not elapsed
        log('Akahu refresh rate limited (cooldown not elapsed)');
        return false;
      } else {
        log('Akahu refresh failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      log('Akahu refresh error: $e');
      return false;
    }
  }

  /// Internal paginated fetch helper for Akahu endpoints.
  static Future<List<Map<String, dynamic>>> _fetchPaginated(
    String appToken,
    String userToken,
    String path, {
    DateTime? start,
    DateTime? end,
  }) async {
    final headers = _headers(appToken, userToken);

    final baseQuery = <String, String>{};
    if (start != null) baseQuery['start'] = start.toUtc().toIso8601String();
    if (end != null) baseQuery['end'] = end.toUtc().toIso8601String();

    final items = <Map<String, dynamic>>[];
    String? cursor;

    do {
      final params = Map<String, String>.from(baseQuery);
      if (cursor != null) params['cursor'] = cursor;

      final uri = Uri.https('api.akahu.io', path, params);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception(
          "Akahu API error: ${response.statusCode} - ${response.body}",
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception("Invalid response format: ${response.body}");
      }

      final pageItems = data['items'];
      if (pageItems is List) {
        items.addAll(pageItems.cast<Map<String, dynamic>>());
      }

      final cursorObj = data['cursor'];
      if (cursorObj is Map<String, dynamic>) {
        cursor = cursorObj['next'] as String?;
      } else {
        cursor = null;
      }
    } while (cursor != null);

    return items;
  }
}
