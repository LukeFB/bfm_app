import 'dart:convert';
import 'package:http/http.dart' as http;

class AkahuService {
  static const String clientId = "<YOUR_CLIENT_ID>"; 
  static const String clientSecret = "<YOUR_CLIENT_SECRET>"; 
  static const String redirectUri = "com.bfm.app://callback"; // must match Akahu settings
  static const String baseUrl = "https://api.akahu.io/v1";

  // Exchange auth code for token
  static Future<String?> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse("$baseUrl/token"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "client_id": clientId,
        "client_secret": clientSecret,
        "redirect_uri": redirectUri,
        "code": code,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["access_token"];
    }
    return null;
  }

  // Fetch accounts
  static Future<List<dynamic>> getAccounts(String accessToken) async {
    final response = await http.get(
      Uri.parse("$baseUrl/accounts"),
      headers: {"Authorization": "Bearer $accessToken"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["items"];
    }
    return [];
  }

  // Fetch transactions
  static Future<List<dynamic>> getTransactions(String accessToken, String accountId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/accounts/$accountId/transactions"),
      headers: {"Authorization": "Bearer $accessToken"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["items"];
    }
    return [];
  }
}
