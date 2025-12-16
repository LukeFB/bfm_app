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
  /// Fetches transactions from Akahu API and returns the `items` array as a
  /// list of maps. Throws when the HTTP status is non-200 or the JSON shape is
  /// unexpected.
  static Future<List<Map<String, dynamic>>> fetchTransactions(
      String appToken, String userToken) async {
    final url = Uri.parse("https://api.akahu.io/v1/transactions");

    final response = await http.get(
      url,
      headers: {
        "X-Akahu-Id": appToken,
        "Authorization": "Bearer $userToken",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Akahu API error: ${response.statusCode} - ${response.body}");
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items']);
    } else {
      throw Exception("Invalid response format: ${response.body}");
    }
  }
}
