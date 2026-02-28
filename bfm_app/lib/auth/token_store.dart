import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the backend JWT access token in secure storage.
///
/// Intentionally separate from [SecureCredentialStore] which manages direct
/// Akahu tokens and OpenAI keys. This store is for the Moni backend session.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'cred.moni.access_token';

  Future<String?> getToken() => _storage.read(key: _key);

  Future<void> setToken(String token) =>
      _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}
