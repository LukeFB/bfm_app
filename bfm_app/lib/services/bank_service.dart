/// ---------------------------------------------------------------------------
/// File: lib/services/bank_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   One-stop shop for nuking bank-connected data so the user can reconnect
///   cleanly without dangling transactions or tokens.
///
/// Called by:
///   `settings_screen.dart` when the user taps “Disconnect bank”.
///
/// Inputs / Outputs:
///   No inputs. Clears SQLite tables, SharedPreferences flags, and secure
///   Akahu tokens. Returns a Future so UI can await completion.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates cleanup when the user disconnects their bank.
class BankService {
  /// Connects Akahu tokens, flips the bank_connected flag, and optionally kicks
  /// off an initial sync pipeline.
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

    if (triggerInitialSync) {
      await TransactionSyncService().syncNow();
    }
  }

  /// Disconnects the current bank session by:
  /// - Clearing transactions, recurring rows, and budgets via repositories
  ///   (keeps repository-level hooks consistent).
  /// - Resetting category usage stats directly in SQLite so future analytics
  ///   start from zero.
  /// - Removing any local “connected” flags and Akahu tokens so the app lands
  ///   back on the Bank Connect screen the next time.
  /// Clears local transactions, budgets, recurring rows, category usage, prefs,
  /// and secure tokens so the next launch behaves like a fresh install.
  static Future<void> disconnect() async {
    // ------ Clear transaction-related tables via repositories ------
    await TransactionRepository.clearAll();
    await RecurringRepository.clearAll();
    await BudgetRepository.clearAll();

    // ------ Reset category usage counters (keep categories themselves) ------
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      'UPDATE categories SET usage_count = 0, last_used_at = NULL;',
    );

    // ------ Clear connection flags / tokens in SharedPreferences ------
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bank_connected', false);
    await prefs.remove('last_sync_at');
    await prefs.remove('akahu_app_token');
    await prefs.remove('akahu_user_token');

    await SecureCredentialStore().clearAkahuTokens();

    // TODO: disconnect akahu clear tokens
  }
}
