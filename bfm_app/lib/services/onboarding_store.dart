/// ---------------------------------------------------------------------------
/// File: lib/services/onboarding_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Wraps `SharedPreferences` to persist the one-time onboarding payload and
///     completion flag so we can skip the flow on subsequent launches.
///
/// Notes:
///   - Stores answers locally only; nothing is synced off-device.
/// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bfm_app/models/onboarding_response.dart';

class OnboardingStore {
  static const String _completeKey = 'onboarding.complete';
  static const String _payloadKey = 'onboarding.payload';

  /// Returns `true` once the user has progressed past the onboarding flow.
  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completeKey) ?? false;
  }

  /// Saves the (optional) answers and flips the completion flag so the user lands
  /// on the bank connection flow next time they unlock the app.
  Future<void> saveResponse(OnboardingResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(response.toJson());
    await Future.wait([
      prefs.setBool(_completeKey, true),
      prefs.setString(_payloadKey, payload),
    ]);
  }

  /// Retrieves the last stored onboarding payload for diagnostics or future UX.
  Future<OnboardingResponse?> getResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_payloadKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return OnboardingResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clears stored answers and completion state (useful for QA/reset flows).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_completeKey), prefs.remove(_payloadKey)]);
  }
}
