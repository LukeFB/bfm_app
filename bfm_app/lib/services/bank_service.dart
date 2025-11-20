/// ---------------------------------------------------------------------------
/// File: lib/services/bank_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Centralise the “disconnect bank” flow so all transaction-related data is
///   removed in one place and the UI can reliably return to Bank Connect.
///
/// Behaviour:
///   - Deletes all rows from: transactions, recurring_transactions, budgets.
///   - Resets categories.usage_count to 0 and clears last_used_at (keeps
///     the user’s category list, colours, icons, etc.).
///   - Clears connection flags in SharedPreferences (bank_connected, last_sync_at,
///     and any stored Akahu tokens if present).
///
/// Notes:
///   - Uses repositories for table clears to preserve existing behaviour.
///   - Leaves categories intact
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BankService {
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
