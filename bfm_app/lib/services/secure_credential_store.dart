import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AkahuTokenPair {
  final String appToken;
  final String userToken;
  const AkahuTokenPair({required this.appToken, required this.userToken});
}

/// Centralises secure storage for API credentials (Akahu + OpenAI).
class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _akahuAppKey = 'cred.akahu.app';
  static const _akahuUserKey = 'cred.akahu.user';
  static const _openAiKeyKey = 'cred.openai.api_key';

  Future<void> saveAkahuTokens({
    required String appToken,
    required String userToken,
  }) async {
    await Future.wait([
      _storage.write(key: _akahuAppKey, value: appToken),
      _storage.write(key: _akahuUserKey, value: userToken),
    ]);
  }

  Future<AkahuTokenPair?> readAkahuTokens() async {
    final values = await _storage.readAll();
    final app = values[_akahuAppKey];
    final user = values[_akahuUserKey];
    if (app == null || app.isEmpty || user == null || user.isEmpty) {
      return null;
    }
    return AkahuTokenPair(appToken: app, userToken: user);
  }

  Future<void> clearAkahuTokens() async {
    await Future.wait([
      _storage.delete(key: _akahuAppKey),
      _storage.delete(key: _akahuUserKey),
    ]);
  }

  Future<void> saveOpenAiKey(String key) async {
    await _storage.write(key: _openAiKeyKey, value: key);
  }

  Future<String?> readOpenAiKey() async {
    return _storage.read(key: _openAiKeyKey);
  }

  Future<void> clearOpenAiKey() async {
    await _storage.delete(key: _openAiKeyKey);
  }
}

