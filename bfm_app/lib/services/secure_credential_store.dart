/// ---------------------------------------------------------------------------
/// File: lib/services/secure_credential_store.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `akahu_service.dart`, `bank_service.dart`, and `api_key_store.dart`.
///
/// Purpose:
///   - Centralises reads/writes to `FlutterSecureStorage` for Akahu tokens and
///     OpenAI keys.
///
/// Inputs:
///   - Token strings provided during onboarding or settings changes.
///
/// Outputs:
///   - Stored credentials plus helper objects for consumers.
/// ---------------------------------------------------------------------------
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Simple tuple representing both Akahu tokens.
class AkahuTokenPair {
  final String appToken;
  final String userToken;
  const AkahuTokenPair({required this.appToken, required this.userToken});
}

/// Thin wrapper around `FlutterSecureStorage` for API credentials.
class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _akahuAppKey = 'cred.akahu.app';
  static const _akahuUserKey = 'cred.akahu.user';
  static const _openAiKeyKey = 'cred.openai.api_key';

  /// Saves both Akahu tokens in parallel.
  Future<void> saveAkahuTokens({
    required String appToken,
    required String userToken,
  }) async {
    await Future.wait([
      _storage.write(key: _akahuAppKey, value: appToken),
      _storage.write(key: _akahuUserKey, value: userToken),
    ]);
  }

  /// Reads both Akahu tokens. Returns null when either piece is missing.
  Future<AkahuTokenPair?> readAkahuTokens() async {
    final values = await _storage.readAll();
    final app = values[_akahuAppKey];
    final user = values[_akahuUserKey];
    if (app == null || app.isEmpty || user == null || user.isEmpty) {
      return null;
    }
    return AkahuTokenPair(appToken: app, userToken: user);
  }

  /// Clears the stored Akahu tokens.
  Future<void> clearAkahuTokens() async {
    await Future.wait([
      _storage.delete(key: _akahuAppKey),
      _storage.delete(key: _akahuUserKey),
    ]);
  }

  /// Saves the OpenAI API key as-is.
  Future<void> saveOpenAiKey(String key) async {
    await _storage.write(key: _openAiKeyKey, value: key);
  }

  /// Reads the OpenAI key if present.
  Future<String?> readOpenAiKey() async {
    return _storage.read(key: _openAiKeyKey);
  }

  /// Removes the stored OpenAI key.
  Future<void> clearOpenAiKey() async {
    await _storage.delete(key: _openAiKeyKey);
  }
}

