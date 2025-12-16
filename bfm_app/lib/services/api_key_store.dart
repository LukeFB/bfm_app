/// ---------------------------------------------------------------------------
/// File: lib/services/api_key_store.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `ai_client.dart` configuration flows that need the OpenAI key.
///
/// Purpose:
///   - Minimal wrapper around `SecureCredentialStore` for storing the API key.
///
/// Inputs:
///   - Raw API key strings.
///
/// Outputs:
///   - Stored/cleared credentials inside secure storage.
///
/// Notes:
///   - MVP-only; revisit before shipping widely.
/// ---------------------------------------------------------------------------
import 'package:bfm_app/services/secure_credential_store.dart';

/// Static helpers for reading/writing the OpenAI key.
class ApiKeyStore {
  static final SecureCredentialStore _store = SecureCredentialStore();

  /// Returns the currently stored API key, if any.
  static Future<String?> get() async {
    return _store.readOpenAiKey();
  }

  /// Saves/replaces the API key.
  static Future<void> set(String key) async {
    await _store.saveOpenAiKey(key);
  }

  /// Removes the stored key entirely.
  static Future<void> clear() async {
    await _store.clearOpenAiKey();
  }
}
