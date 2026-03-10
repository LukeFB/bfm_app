import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's email and password in secure storage so the app can
/// auto-sign-in when the JWT session expires without prompting the user.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _emailKey = 'cred.moni.email';
  static const _passwordKey = 'cred.moni.password';

  Future<String?> getEmail() => _storage.read(key: _emailKey);
  Future<String?> getPassword() => _storage.read(key: _passwordKey);

  /// Returns true when both email and password are stored.
  Future<bool> hasCredentials() async {
    final results = await Future.wait([
      _storage.read(key: _emailKey),
      _storage.read(key: _passwordKey),
    ]);
    return results[0] != null &&
        results[0]!.isNotEmpty &&
        results[1] != null &&
        results[1]!.isNotEmpty;
  }

  /// Saves email and password for auto-sign-in.
  Future<void> saveCredentials(String email, String password) async {
    await Future.wait([
      _storage.write(key: _emailKey, value: email),
      _storage.write(key: _passwordKey, value: password),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _emailKey),
      _storage.delete(key: _passwordKey),
    ]);
  }
}
