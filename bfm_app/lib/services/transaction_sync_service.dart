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

import 'package:bfm_app/api/akahu_api.dart';
import 'package:bfm_app/api/api_client.dart';
import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/services/income_settings_store.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs Akahu data into the local database.
///
/// Tries the backend-proxied path first (JWT in TokenStore). Falls back to
/// direct Akahu API calls using raw tokens for dev/manual-token connections.
class TransactionSyncService {
  static const _lastSyncKey = 'last_sync_at';
  static const _lastRefreshKey = 'last_refresh_triggered_at';
  static const _backfillCompleteKey = 'tx_backfill_complete';
  static const Duration _rollingWindow = Duration(days: 120);
  static const Duration _initialBackfillWindow = Duration(days: 365);
  static const Duration _defaultStaleThreshold = Duration(hours: 1);
  static const Duration _refreshCooldown = Duration(hours: 1);

  TransactionSyncService({SecureCredentialStore? credentialStore})
      : _credentialStore = credentialStore ?? SecureCredentialStore();

  final SecureCredentialStore _credentialStore;

  /// Pulls accounts + transactions and writes them to the local DB.
  ///
  /// Uses the backend when a JWT exists, otherwise falls back to direct tokens.
  Future<void> syncNow({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) {
      log('Skipping sync: bank not connected.');
      return;
    }

    // Try backend-proxied path first
    final backendToken = await TokenStore().getToken();
    if (backendToken != null && backendToken.isNotEmpty) {
      try {
        await _syncViaBackend();
        return;
      } catch (e) {
        log('Backend sync failed, trying direct: $e');
      }
    }

    // Fall back to direct Akahu tokens
    await _syncViaDirect(prefs, forceRefresh);
  }

  // ── Backend-proxied sync ──────────────────────────────────────────────────

  Future<void> _syncViaBackend() async {
    final tokenStore = TokenStore();
    final client = ApiClient(tokenStore: tokenStore);
    final api = AkahuApi(client);

    final results = await Future.wait([
      api.accounts(),
      api.transactions(),
    ]);

    final accountPayloads = results[0];
    final txnPayloads = results[1];

    log('Backend sync: ${accountPayloads.length} accounts, '
        '${txnPayloads.length} transactions');

    // Log a sample transaction so we can verify the JSON shape matches fromAkahu
    if (txnPayloads.isNotEmpty) {
      log('Sample txn keys: ${txnPayloads.first.keys.toList()}');
    }
    if (accountPayloads.isNotEmpty) {
      log('Sample account keys: ${accountPayloads.first.keys.toList()}');
    }

    if (accountPayloads.isNotEmpty) {
      await AccountRepository.upsertFromAkahu(accountPayloads);
    }
    if (txnPayloads.isNotEmpty) {
      await TransactionRepository.upsertFromAkahu(txnPayloads);
    }

    // Same post-processing as the direct path
    await IncomeSettingsStore.detectAndSetIncomeType();
    await _markSynced(markBackfillComplete: true);
  }

  // ── Direct Akahu sync (dev/manual tokens) ─────────────────────────────────

  Future<void> _syncViaDirect(SharedPreferences prefs, bool forceRefresh) async {
    final tokens = await _credentialStore.readAkahuTokens();
    if (tokens == null) {
      log('Skipping sync: no Akahu tokens and no backend JWT.');
      return;
    }

    await _maybeRefresh(tokens.appToken, tokens.userToken, prefs, forceRefresh);

    final nowUtc = DateTime.now().toUtc();
    final hasBackfilled = prefs.getBool(_backfillCompleteKey) ?? false;
    final usedBackfillWindow = !hasBackfilled;
    final windowStart = nowUtc.subtract(
      hasBackfilled ? _rollingWindow : _initialBackfillWindow,
    );

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

    for (final payload in pendingPayloads) {
      payload['_pending'] = true;
    }

    final allPayloads = [...settledPayloads, ...pendingPayloads];

    log('Direct sync: ${settledPayloads.length} settled + '
        '${pendingPayloads.length} pending txns, '
        '${accountPayloads.length} accounts');

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
  Future<bool> syncIfStale({Duration? maxAge}) async {
    maxAge ??= _defaultStaleThreshold;

    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) return false;

    // Need either a backend JWT or direct Akahu tokens
    final backendToken = await TokenStore().getToken();
    final hasBackend = backendToken != null && backendToken.isNotEmpty;
    final hasDirectTokens = (await _credentialStore.readAkahuTokens()) != null;
    if (!hasBackend && !hasDirectTokens) return false;

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

