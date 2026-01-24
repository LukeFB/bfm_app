/// ---------------------------------------------------------------------------
/// File: lib/services/transaction_sync_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Handles the actual "pull transactions from Akahu and persist them" flow.
///   Fetches BOTH pending and settled transactions for maximum freshness.
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

import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stateless-ish service with a dependency-injected credential store for tests.
class TransactionSyncService {
  static const _lastSyncKey = 'last_sync_at';
  static const _lastRefreshKey = 'last_refresh_triggered_at';
  static const _backfillCompleteKey = 'tx_backfill_complete';
  static const Duration _rollingWindow = Duration(days: 120); // ~4 months
  static const Duration _initialBackfillWindow = Duration(days: 365);

  /// Reduced from 24h to 1h for fresher data. Akahu's personal app refresh
  /// cooldown is 1h, so this aligns with the minimum useful interval.
  static const Duration _defaultStaleThreshold = Duration(hours: 1);

  /// Akahu personal apps have a 1-hour cooldown between manual refreshes.
  /// Full apps have 15-min cooldown (configurable).
  static const Duration _refreshCooldown = Duration(hours: 1);

  /// Accepts a custom credential store for tests; defaults to the real one.
  TransactionSyncService({SecureCredentialStore? credentialStore})
      : _credentialStore = credentialStore ?? SecureCredentialStore();

  final SecureCredentialStore _credentialStore;

  /// Pulls transactions immediately:
  /// - Verifies we have active tokens + are marked connected.
  /// - Triggers a manual refresh if cooldown has elapsed (gets freshest data).
  /// - Fetches BOTH pending AND settled transactions from Akahu.
  /// - Upserts them via the repository and records the last-sync timestamp.
  Future<void> syncNow({bool forceRefresh = false}) async {
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

    // Trigger a manual refresh to get the latest data from the bank
    // (respects cooldown to avoid rate limiting)
    await _maybeRefresh(tokens.appToken, tokens.userToken, prefs, forceRefresh);

    final nowUtc = DateTime.now().toUtc();
    final hasBackfilled = prefs.getBool(_backfillCompleteKey) ?? false;
    final usedBackfillWindow = !hasBackfilled;
    final windowStart = nowUtc.subtract(
      hasBackfilled ? _rollingWindow : _initialBackfillWindow,
    );

    // Fetch transactions, pending transactions, AND accounts in parallel
    final results = await Future.wait([
      AkahuService.fetchTransactions(
        tokens.appToken,
        tokens.userToken,
        start: windowStart,
        end: nowUtc,
      ),
      AkahuService.fetchPendingTransactions(
        tokens.appToken,
        tokens.userToken,
      ),
      AkahuService.fetchAccounts(
        tokens.appToken,
        tokens.userToken,
      ),
    ]);

    final settledPayloads = results[0];
    final pendingPayloads = results[1];
    final accountPayloads = results[2];

    // Mark pending transactions so we can identify them in the UI if needed
    for (final payload in pendingPayloads) {
      payload['_pending'] = true;
    }

    final allPayloads = [...settledPayloads, ...pendingPayloads];

    log('Synced ${settledPayloads.length} settled + ${pendingPayloads.length} pending transactions, ${accountPayloads.length} accounts');

    // Sync accounts (even if no transactions)
    if (accountPayloads.isNotEmpty) {
      await AccountRepository.upsertFromAkahu(accountPayloads);
    }

    if (allPayloads.isEmpty) {
      await _markSynced(markBackfillComplete: usedBackfillWindow);
      return;
    }

    await TransactionRepository.upsertFromAkahu(allPayloads);
    await _markSynced(markBackfillComplete: usedBackfillWindow);
  }

  /// Triggers a manual Akahu data refresh if the cooldown has elapsed.
  /// This tells Akahu to fetch fresh data from the user's bank.
  Future<void> _maybeRefresh(
    String appToken,
    String userToken,
    SharedPreferences prefs,
    bool force,
  ) async {
    final lastRefreshIso = prefs.getString(_lastRefreshKey);

    if (!force && lastRefreshIso != null) {
      final lastRefresh = DateTime.tryParse(lastRefreshIso);
      if (lastRefresh != null &&
          DateTime.now().difference(lastRefresh) < _refreshCooldown) {
        log('Skipping refresh: cooldown not elapsed');
        return;
      }
    }

    final success = await AkahuService.triggerRefresh(appToken, userToken);
    if (success) {
      await prefs.setString(_lastRefreshKey, DateTime.now().toIso8601String());
    }
  }

  /// Checks when we last synced and only calls `syncNow` if the delta exceeds
  /// `maxAge`. Returns true when a sync was kicked off.
  ///
  /// Default maxAge reduced to 1 hour for fresher transaction data.
  Future<bool> syncIfStale({Duration? maxAge}) async {
    maxAge ??= _defaultStaleThreshold;

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
  Future<void> _markSynced({bool markBackfillComplete = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    if (markBackfillComplete) {
      await prefs.setBool(_backfillCompleteKey, true);
    }
  }
}

