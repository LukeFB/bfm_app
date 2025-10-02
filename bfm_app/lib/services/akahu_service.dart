import 'dart:convert';
import 'package:http/http.dart' as http;

class AkahuService {
  /// Fetches transactions from Akahu API.
  /// [appToken] = X-Akahu-Id header
  /// [userToken] = Bearer token
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
