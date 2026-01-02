/// ---------------------------------------------------------------------------
/// File: lib/services/akahu_service.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `transaction_sync_service.dart` when pulling new bank data.
///
/// Purpose:
///   - Minimal HTTP client for the Akahu transactions endpoint.
///
/// Inputs:
///   - App token (`X-Akahu-Id`) and user Bearer token.
///
/// Outputs:
///   - Parsed transaction JSON payloads.
/// ---------------------------------------------------------------------------
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Wraps Akahu HTTP calls behind a static helper.
class AkahuService {
  /// Fetches transactions from Akahu API using cursor pagination so we cover
  /// the entire requested window. Optional [start]/[end] map to Akahu's query
  /// params and default to the provider's standard range when omitted.
  static Future<List<Map<String, dynamic>>> fetchTransactions(
    String appToken,
    String userToken, {
    DateTime? start,
    DateTime? end,
  }) async {
    final headers = {
      "X-Akahu-Id": appToken,
      "Authorization": "Bearer $userToken",
    };

    final baseQuery = <String, String>{};
    if (start != null) baseQuery['start'] = start.toUtc().toIso8601String();
    if (end != null) baseQuery['end'] = end.toUtc().toIso8601String();

    final items = <Map<String, dynamic>>[];
    String? cursor;

    do {
      final params = Map<String, String>.from(baseQuery);
      if (cursor != null) params['cursor'] = cursor;

      final uri = Uri.https('api.akahu.io', '/v1/transactions', params);
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
