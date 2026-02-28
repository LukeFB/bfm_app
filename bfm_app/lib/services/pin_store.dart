/// ---------------------------------------------------------------------------
/// File: lib/services/pin_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Wraps `FlutterSecureStorage` so PIN state lives in one secure location.
///   Handles hashing, salting, and constant-time comparison.
///
/// Called by:
///   `app.dart`, `enter_pin_screen.dart`, and `set_pin_screen.dart` when
///   locking, unlocking, or updating the user's local PIN.
///
/// Inputs / Outputs:
///   Exposes async helpers that read/write hashed PIN data. Never returns
///   the raw PIN, only booleans for checks.
/// ---------------------------------------------------------------------------
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and validates the user's app-specific PIN with a salt+hash combo.
class PinStore {
  /// Allow dependency injection for tests while using the real secure storage
  /// in production builds.
  PinStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _pinKey = 'lockgate.pin.hash';
  static const String _saltKey = 'lockgate.pin.salt';
  static const String _lastAuthKey = 'lockgate.last_auth_ms';

  static const Duration gracePeriod = Duration(minutes: 5);

  final FlutterSecureStorage _storage;

  /// Returns `true` when a hashed PIN is present.
  /// Keeps screens lightweight by avoiding manual key lookups.
  Future<bool> hasPin() async {
    return _storage.containsKey(key: _pinKey);
  }

  /// Hashes and stores the provided `pin`.
  /// - Generates a fresh salt for every save.
  /// - Writes hash + salt in parallel to secure storage.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await Future.wait([
      _storage.write(key: _pinKey, value: hash),
      _storage.write(key: _saltKey, value: salt),
    ]);
  }

  /// Validates user input by:
  /// - Loading the stored salt + hash.
  /// - Recomputing a hash with the supplied `pin`.
  /// - Running a constant-time check to avoid timing attacks.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _pinKey);
    if (salt == null || storedHash == null) {
      return false;
    }

    final hash = _hashPin(pin, salt);
    return _constantTimeEquals(hash, storedHash);
  }

  /// Stamps the current time so the grace period window starts now.
  Future<void> recordAuthSuccess() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _lastAuthKey, value: now);
  }

  /// Returns `true` when the last successful auth is within [gracePeriod].
  Future<bool> isWithinGracePeriod() async {
    final raw = await _storage.read(key: _lastAuthKey);
    if (raw == null) return false;
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
    return DateTime.now().difference(lastAuth) < gracePeriod;
  }

  /// Completely removes the stored hash and salt so the app behaves like
  /// no PIN was ever set.
  Future<void> clearPin() async {
    await Future.wait([
      _storage.delete(key: _pinKey),
      _storage.delete(key: _saltKey),
      _storage.delete(key: _lastAuthKey),
    ]);
  }

  /// Creates a SHA-256 hash by concatenating `salt|pin`.
  /// Keeps the encoding format stable so verification is deterministic.
  String _hashPin(String pin, String salt) {
    final payload = utf8.encode('$salt|$pin');
    final digest = sha256.convert(payload);
    return digest.toString();
  }

  /// Generates a cryptographically secure salt of `length` bytes and encodes
  /// it using URL-safe base64 so it can live in FlutterSecureStorage.
  String _generateSalt({int length = 16}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// Compares two strings without leaking timing differences so brute-force
  /// attempts cannot infer shared prefixes.
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

