/// ---------------------------------------------------------------------------
/// File: lib/services/secure_credential_store.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `akahu_service.dart`, `bank_service.dart`.
///
/// Purpose:
///   - Centralises reads/writes to `FlutterSecureStorage` for Akahu tokens.
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
}
