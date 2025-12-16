/// ---------------------------------------------------------------------------
/// File: lib/services/transaction_sync_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Handles the actual "pull transactions from Akahu and persist them" flow.
///
/// Called by:
///   `dashboard_screen.dart` (auto refresh) and `bank_connect_screen.dart`
///   (after linking a bank).
///
/// Inputs / Outputs:
///   Reads Akahu tokens from `SecureCredentialStore`, writes transactions via
///   `TransactionRepository`, and stores sync timestamps in SharedPreferences.
/// ---------------------------------------------------------------------------
import 'dart:developer';

import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stateless-ish service with a dependency-injected credential store for tests.
class TransactionSyncService {
  /// Accepts a custom credential store for tests; defaults to the real one.
  TransactionSyncService({SecureCredentialStore? credentialStore})
      : _credentialStore = credentialStore ?? SecureCredentialStore();

  final SecureCredentialStore _credentialStore;
  static const _lastSyncKey = 'last_sync_at';

  /// Pulls transactions immediately:
  /// - Verifies we have active tokens + are marked connected.
  /// - Fetches Akahu transactions.
  /// - Upserts them via the repository and records the last-sync timestamp.
  Future<void> syncNow() async {
    final tokens = await _credentialStore.readAkahuTokens();
    if (tokens == null) {
      throw Exception('No Akahu tokens stored. Please reconnect your bank.');
    }

    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) {
      log('Skipping sync: bank not connected.');
      return;
    }

    final payloads =
        await AkahuService.fetchTransactions(tokens.appToken, tokens.userToken);

    if (payloads.isEmpty) {
      await _markSynced();
      return;
    }

    await TransactionRepository.upsertFromAkahu(payloads);
    await _markSynced();
  }

  /// Checks when we last synced and only calls `syncNow` if the delta exceeds
  /// `maxAge`. Returns true when a sync was kicked off.
  Future<bool> syncIfStale({Duration maxAge = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) {
      return false;
    }

    final tokens = await _credentialStore.readAkahuTokens();
    if (tokens == null) {
      return false;
    }

    final lastSyncIso = prefs.getString(_lastSyncKey);
    if (lastSyncIso == null) {
      await syncNow();
      return true;
    }

    final lastSync = DateTime.tryParse(lastSyncIso);
    if (lastSync == null || DateTime.now().difference(lastSync) > maxAge) {
      await syncNow();
      return true;
    }
    return false;
  }

  /// Writes the ISO timestamp of the latest sync to SharedPreferences so the
  /// next `syncIfStale` call has a comparison point.
  Future<void> _markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }
}

