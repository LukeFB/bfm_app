import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and validates the user's app-specific PIN.
class PinStore {
  PinStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _pinKey = 'lockgate.pin.hash';
  static const String _saltKey = 'lockgate.pin.salt';

  final FlutterSecureStorage _storage;

  Future<bool> hasPin() async {
    return _storage.containsKey(key: _pinKey);
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await Future.wait([
      _storage.write(key: _pinKey, value: hash),
      _storage.write(key: _saltKey, value: salt),
    ]);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _pinKey);
    if (salt == null || storedHash == null) {
      return false;
    }

    final hash = _hashPin(pin, salt);
    return _constantTimeEquals(hash, storedHash);
  }

  Future<void> clearPin() async {
    await Future.wait([
      _storage.delete(key: _pinKey),
      _storage.delete(key: _saltKey),
    ]);
  }

  String _hashPin(String pin, String salt) {
    final payload = utf8.encode('$salt|$pin');
    final digest = sha256.convert(payload);
    return digest.toString();
  }

  String _generateSalt({int length = 16}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

