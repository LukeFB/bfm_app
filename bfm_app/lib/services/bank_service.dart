/// ---------------------------------------------------------------------------
/// File: lib/services/bank_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   One-stop shop for nuking bank-connected data so the user can reconnect
///   cleanly without dangling transactions or tokens.
///
/// Called by:
///   `settings_screen.dart` when the user taps "Disconnect bank".
///
/// Inputs / Outputs:
///   No inputs. Clears SQLite tables, SharedPreferences flags, and secure
///   Akahu tokens. Returns a Future so UI can await completion.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/asset_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/event_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/budget_buffer_store.dart';
import 'package:bfm_app/services/budget_seen_store.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/income_settings_store.dart';
import 'package:bfm_app/services/manual_budget_store.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/services/debug_log.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates cleanup when the user disconnects their bank.
///
/// TODO: For production, call AkahuApi.revoke() (via AkahuController) to
/// revoke the backend Akahu session before clearing local data. Currently
/// only clears local state. Also add AccountRepository removal for backend-
/// synced accounts.
class BankService {
  /// Connects Akahu tokens, flips the bank_connected flag, and optionally kicks
  /// off an initial sync pipeline.
  ///
  /// After syncing transactions, automatically detects whether the user has
  /// regular or non-regular income based on their transaction history.
  static Future<void> connect({
    required String appToken,
    required String userToken,
    bool triggerInitialSync = true,
  }) async {
    if (appToken.isEmpty || userToken.isEmpty) {
      throw ArgumentError('Both Akahu tokens are required.');
    }

    await SecureCredentialStore().saveAkahuTokens(
      appToken: appToken,
      userToken: userToken,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bank_connected', true);
    await prefs.remove('last_sync_at');

    await WeeklyOverviewService.suppressInitialOverview();

    if (triggerInitialSync) {
      await _syncUntilMinTransactions();

      // Auto-detect income regularity after transactions are synced
      await IncomeSettingsStore.detectAndSetIncomeType();
    }
  }

  /// Minimum number of transactions we expect after a fresh bank connection.
  /// Akahu sometimes returns a tiny first batch while it's still fetching
  /// from the user's bank. We retry until we hit this threshold.
  static const int _minTransactions = 100;
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 5);

  /// Syncs repeatedly until at least [_minTransactions] are stored locally,
  /// or until [_maxRetries] attempts have been exhausted.
  static Future<void> _syncUntilMinTransactions() async {
    final syncService = TransactionSyncService();

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      await syncService.syncNow();

      final txCount = await TransactionRepository.count();
      DebugLog.instance.add('SYNC',
          'Initial sync attempt $attempt/$_maxRetries – $txCount transactions');

      if (txCount >= _minTransactions) return;

      if (attempt < _maxRetries) {
        DebugLog.instance.add('SYNC',
            'Only $txCount txns (need $_minTransactions), '
            'retrying in ${_retryDelay.inSeconds}s…');
        await Future.delayed(_retryDelay);
      }
    }

    final finalCount = await TransactionRepository.count();
    DebugLog.instance.add('SYNC',
        'Gave up after $_maxRetries attempts with $finalCount transactions');
  }

  /// Disconnects the current bank session by:
  /// - Clearing all user data (transactions, budgets, goals, alerts, assets,
  ///   weekly reports, chat history, onboarding data, etc.)
  /// - Resetting category usage stats directly in SQLite so future analytics
  ///   start from zero.
  /// - Removing any local "connected" flags and Akahu tokens so the app lands
  ///   back on the Bank Connect screen the next time.
  ///
  /// Note: OpenAI API key is intentionally preserved so users don't need to
  /// re-enter it when reconnecting.
  static Future<void> disconnect() async {
    // ------ Clear all SQLite tables via repositories ------
    // Order matters due to foreign key constraints:
    // 1. Clear budgets first (references goals, recurring_transactions)
    // 2. Clear alerts (references recurring_transactions)
    // 3. Clear goals (clears goal_progress_log internally)
    // 4. Clear recurring_transactions
    // 5. Clear remaining tables
    await BudgetRepository.clearAll();
    await AlertRepository.clearAll();
    await GoalRepository.clearAll();
    await RecurringRepository.clearAll();
    await TransactionRepository.clearAll();
    await AccountRepository.clearAll();
    await AssetRepository.clearAll();
    await WeeklyReportRepository.clearAll();
    await EventRepository.clearAll();

    // ------ Reset category usage counters (keep categories themselves) ------
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      'UPDATE categories SET usage_count = 0, last_used_at = NULL;',
    );

    // ------ Clear chat history ------
    await ChatStorage().clear();

    // ------ Clear onboarding data ------
    await OnboardingStore().reset();

    // ------ Clear budget seen state ------
    await BudgetSeenStore.clearAll();

    // ------ Clear manual budgets ------
    await ManualBudgetStore.clearAll();

    // ------ Clear app savings and budget buffers ------
    await AppSavingsStore.clear();
    await BudgetBufferStore.clear();

    // ------ Clear income settings ------
    await IncomeSettingsStore.clear();

    // ------ Clear connection flags / tokens in SharedPreferences ------
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bank_connected', false);
    await prefs.remove('last_sync_at');
    await prefs.remove('akahu_app_token');
    await prefs.remove('akahu_user_token');
    // Clear sync-related flags
    await prefs.remove('last_refresh_triggered_at');
    await prefs.remove('tx_backfill_complete');
    // Clear weekly overview state
    await prefs.remove('weekly_overview_last_week');
    // Clear savings screen preference
    await prefs.remove('savings_profit_loss_time_frame');

    // ------ Clear Akahu tokens from secure storage ------
    // Note: OpenAI API key is intentionally NOT cleared
    await SecureCredentialStore().clearAkahuTokens();
  }
}
