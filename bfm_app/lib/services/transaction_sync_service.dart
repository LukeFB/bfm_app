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
import 'dart:async';
import 'dart:developer';

import 'package:bfm_app/api/akahu_api.dart';
import 'package:bfm_app/api/api_client.dart';
import 'package:bfm_app/auth/token_store.dart';
import 'package:bfm_app/services/debug_log.dart';
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

  /// Don't mark the initial 365-day backfill as complete until the local DB
  /// has at least this many transactions. Prevents premature switch to the
  /// shorter rolling window when Akahu is still fetching from the bank.
  static const int _minInitialTransactions = 100;

  static bool _syncing = false;
  static Future<void>? _activeSyncFuture;

  /// Whether a sync is currently in progress.
  static bool get isSyncing => _syncing;

  /// Returns a Future that completes when the most recent sync finishes.
  /// Resolves immediately if no sync has been started.
  static Future<void> waitForSync() => _activeSyncFuture ?? Future.value();

  TransactionSyncService({SecureCredentialStore? credentialStore})
      : _credentialStore = credentialStore ?? SecureCredentialStore();

  final SecureCredentialStore _credentialStore;

  /// Pulls accounts + transactions and writes them to the local DB.
  ///
  /// Uses the backend when a JWT exists, otherwise falls back to direct tokens.
  /// Guarded against concurrent runs – a second call while one is in progress
  /// returns immediately.
  Future<void> syncNow({bool forceRefresh = false}) async {
    if (_syncing) {
      log('Sync already in progress – skipping.');
      return;
    }
    _syncing = true;
    final completer = Completer<void>();
    // Ignore errors on the future itself so Dart doesn't report unhandled
    // exceptions. Callers of waitForSync() handle errors themselves.
    _activeSyncFuture = completer.future.catchError((_) {});
    try {
      await _syncNowInner(forceRefresh: forceRefresh);
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncNowInner({bool forceRefresh = false}) async {
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
        DebugLog.instance.add('SYNC', 'Backend sync failed: $e');
      }
    }

    // Fall back to direct Akahu tokens
    await _syncViaDirect(prefs, forceRefresh);
  }

  // ── Backend-proxied sync ──────────────────────────────────────────────────

  Future<void> _syncViaBackend() async {
    final syncStart = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final tokenStore = TokenStore();
    final client = ApiClient(tokenStore: tokenStore);
    final api = AkahuApi(client);

    final nowUtc = DateTime.now().toUtc();
    final hasBackfilled = prefs.getBool(_backfillCompleteKey) ?? false;
    final usedBackfillWindow = !hasBackfilled;
    final windowStart = nowUtc.subtract(
      hasBackfilled ? _rollingWindow : _initialBackfillWindow,
    );

    final window = hasBackfilled ? '120d' : '365d';
    DebugLog.instance.add('SYNC', 'Backend sync starting ($window window)');

    final results = await Future.wait([
      api.accounts(),
      api.transactions(start: windowStart, end: nowUtc),
      api.pendingTransactions(),
    ]);

    final accountPayloads = results[0];
    var settledPayloads = results[1];
    final pendingPayloads = results[2];

    // If the date-windowed call returned nothing, retry without date params.
    // Some backends or Akahu proxy implementations handle the unfiltered
    // endpoint differently and may return data when the filtered one doesn't.
    if (settledPayloads.isEmpty && pendingPayloads.isEmpty) {
      try {
        settledPayloads = await api.transactions();
      } catch (_) {}
    }

    for (final payload in pendingPayloads) {
      payload['_pending'] = true;
    }

    final allTxnPayloads = [...settledPayloads, ...pendingPayloads];

    final fetchMs = DateTime.now().difference(syncStart).inMilliseconds;
    log('Backend sync: ${accountPayloads.length} accounts, '
        '${settledPayloads.length} settled + '
        '${pendingPayloads.length} pending transactions '
        '(window: $window)');

    if (accountPayloads.isNotEmpty) {
      await AccountRepository.upsertFromAkahu(accountPayloads);
    }
    if (allTxnPayloads.isNotEmpty) {
      await TransactionRepository.upsertFromAkahu(allTxnPayloads);
    }

    final gotTransactions = allTxnPayloads.isNotEmpty;
    if (gotTransactions) {
      await IncomeSettingsStore.detectAndSetIncomeType();
    }
    // Only mark synced/backfilled when we have a meaningful number of
    // transactions. On a fresh connection Akahu may still be fetching from
    // the bank, returning a tiny batch first. Keeping the backfill flag
    // false preserves the full 365-day window for subsequent retries.
    final totalStored = await TransactionRepository.count();
    final enoughForBackfill = totalStored >= _minInitialTransactions;
    await _markSynced(
      markBackfillComplete: usedBackfillWindow && enoughForBackfill,
      skipTimestamp: !gotTransactions,
    );

    final totalMs = DateTime.now().difference(syncStart).inMilliseconds;
    DebugLog.instance.add('SYNC',
        'Done: ${accountPayloads.length} accts, '
        '${settledPayloads.length}+${pendingPayloads.length} txns '
        '(fetch ${fetchMs}ms, total ${totalMs}ms)');
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
      await _markSynced(
        markBackfillComplete: false,
        skipTimestamp: true,
      );
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
  ///
  /// When [skipTimestamp] is true the last-sync timestamp is NOT updated,
  /// which lets `syncIfStale` re-trigger quickly (used when Akahu returns
  /// 0 transactions on a fresh connection).
  Future<void> _markSynced({
    bool markBackfillComplete = false,
    bool skipTimestamp = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!skipTimestamp) {
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    }
    if (markBackfillComplete) {
      await prefs.setBool(_backfillCompleteKey, true);
    }
  }
}

