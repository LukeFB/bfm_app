/// ---------------------------------------------------------------------------
/// File: lib/services/api_key_store.dart
/// Author: Luke Fraser-Brown
///
/// MVP-only: stores key in SharedPreferences (not secure).
/// Swap to flutter_secure_storage before production.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/services/secure_credential_store.dart';

class ApiKeyStore {
  static final SecureCredentialStore _store = SecureCredentialStore();

  static Future<String?> get() async {
    return _store.readOpenAiKey();
  }

  static Future<void> set(String key) async {
    await _store.saveOpenAiKey(key);
  }

  static Future<void> clear() async {
    await _store.clearOpenAiKey();
  }
}
