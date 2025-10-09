/// ---------------------------------------------------------------------------
/// File: lib/services/api_key_store.dart
/// Author: Luke Fraser-Brown
///
/// MVP-only: stores key in SharedPreferences (not secure).
/// Swap back to flutter_secure_storage when Android build is sorted.
/// ---------------------------------------------------------------------------
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyStore {
  static const _k = 'bfm_openai_api_key_v1';

  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_k);
  }

  static Future<void> set(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k, key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k);
  }
}
