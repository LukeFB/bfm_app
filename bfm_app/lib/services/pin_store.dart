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
/// Includes brute-force protection with exponential lockout after failed attempts.
class PinStore {
  /// Allow dependency injection for tests while using the real secure storage
  /// in production builds.
  PinStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _pinKey = 'lockgate.pin.hash';
  static const String _saltKey = 'lockgate.pin.salt';
  static const String _lastAuthKey = 'lockgate.last_auth_ms';
  static const String _failedAttemptsKey = 'lockgate.failed_attempts';
  static const String _lockoutUntilKey = 'lockgate.lockout_until_ms';

  static const Duration gracePeriod = Duration(minutes: 5);
  static const int maxAttemptsBeforeLockout = 5;
  static const int maxAttemptsBeforeWipe = 15;

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

  /// Returns the number of consecutive failed attempts.
  Future<int> getFailedAttempts() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    return raw != null ? (int.tryParse(raw) ?? 0) : 0;
  }

  /// Returns `null` if not locked, otherwise the [DateTime] the lockout expires.
  Future<DateTime?> getLockoutEnd() async {
    final raw = await _storage.read(key: _lockoutUntilKey);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(ms);
    return end.isAfter(DateTime.now()) ? end : null;
  }

  /// Returns the lockout duration for the given attempt count.
  /// 5 failures → 30s, 6 → 60s, 7 → 120s, 8 → 300s, 9+ → 600s.
  static Duration lockoutDuration(int attempts) {
    if (attempts < maxAttemptsBeforeLockout) return Duration.zero;
    final tier = attempts - maxAttemptsBeforeLockout;
    const durations = [
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 120),
      Duration(seconds: 300),
    ];
    return tier < durations.length ? durations[tier] : const Duration(seconds: 600);
  }

  /// Validates user input with brute-force protection.
  /// Returns `true` on match, `false` on mismatch. Throws [PinLockedException]
  /// if the account is currently locked out, or [PinWipedException] if too many
  /// failures triggered a data wipe.
  Future<bool> verifyPin(String pin) async {
    // Check lockout first.
    final lockoutEnd = await getLockoutEnd();
    if (lockoutEnd != null) {
      throw PinLockedException(lockoutEnd);
    }

    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _pinKey);
    if (salt == null || storedHash == null) {
      return false;
    }

    final hash = _hashPin(pin, salt);
    final ok = _constantTimeEquals(hash, storedHash);

    if (ok) {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);
      return true;
    }

    // Handle failure.
    final attempts = (await getFailedAttempts()) + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());

    if (attempts >= maxAttemptsBeforeWipe) {
      await clearPin();
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockoutUntilKey);
      throw PinWipedException();
    }

    if (attempts >= maxAttemptsBeforeLockout) {
      final duration = lockoutDuration(attempts);
      final until = DateTime.now().add(duration);
      await _storage.write(
        key: _lockoutUntilKey,
        value: until.millisecondsSinceEpoch.toString(),
      );
    }

    return false;
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

  /// Completely removes the stored hash, salt, and lockout state so the app
  /// behaves like no PIN was ever set.
  Future<void> clearPin() async {
    await Future.wait([
      _storage.delete(key: _pinKey),
      _storage.delete(key: _saltKey),
      _storage.delete(key: _lastAuthKey),
      _storage.delete(key: _failedAttemptsKey),
      _storage.delete(key: _lockoutUntilKey),
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

  /// Compares two strings in constant time regardless of where they differ.
  bool _constantTimeEquals(String a, String b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    var diff = a.length ^ b.length;
    for (var i = 0; i < maxLen; i++) {
      final ca = i < a.length ? a.codeUnitAt(i) : 0;
      final cb = i < b.length ? b.codeUnitAt(i) : 0;
      diff |= ca ^ cb;
    }
    return diff == 0;
  }
}

/// Thrown when PIN entry is temporarily locked after too many failed attempts.
class PinLockedException implements Exception {
  final DateTime lockoutEnd;
  PinLockedException(this.lockoutEnd);

  Duration get remaining => lockoutEnd.difference(DateTime.now());

  @override
  String toString() {
    final secs = remaining.inSeconds;
    if (secs <= 0) return 'Lockout expired.';
    if (secs < 60) return 'Too many attempts. Try again in ${secs}s.';
    return 'Too many attempts. Try again in ${remaining.inMinutes + 1} min.';
  }
}

/// Thrown when the maximum failure threshold is reached and the PIN is wiped.
class PinWipedException implements Exception {
  @override
  String toString() =>
      'Too many failed attempts. PIN has been reset for security. Please sign in again.';
}

