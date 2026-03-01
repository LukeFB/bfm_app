import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's email and password in secure storage so the
/// login screen can auto-fill after a session expires.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _emailKey = 'cred.moni.email';
  static const _passwordKey = 'cred.moni.password';

  Future<String?> getEmail() => _storage.read(key: _emailKey);
  Future<String?> getPassword() => _storage.read(key: _passwordKey);

  Future<void> save({required String email, required String password}) async {
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
