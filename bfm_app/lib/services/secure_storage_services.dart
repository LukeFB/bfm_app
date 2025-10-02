/// ---------------------------------------------------------------------------
/// File: secure_storage_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Securely store and retrieve sensitive information (like API access tokens) 
///   using the device's secure storage. This prevents tokens from being exposed 
///   in plain text on the device storage.
/// 
/// Notes:
///   - Uses `flutter_secure_storage` (or a similar secure storage plugin) to 
///     store data in a platform-specific secure enclave/keychain.
///   - All methods are static for ease of use. In a larger app, this could be 
///     replaced with a more robust authentication manager or state management.
/// ---------------------------------------------------------------------------

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // Create a single instance of FlutterSecureStorage
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'akahu_access_token';

  /// Save the Akahu access [token] securely.
  static Future<void> saveAkahuToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieve the stored Akahu access token, or null if not set.
  static Future<String?> getAkahuToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Delete the stored Akahu access token (e.g., on logout or revocation).
  static Future<void> clearAkahuToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
