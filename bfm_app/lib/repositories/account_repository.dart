/// ---------------------------------------------------------------------------
/// File: lib/repositories/account_repository.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Sync flows, savings screen, dashboard services.
///
/// Purpose:
///   - Centralises all reads/writes for the `accounts` table.
///   - Handles upserting Akahu account data and aggregating balances.
///
/// Inputs:
///   - Raw Akahu account payloads, AccountModel instances.
///
/// Outputs:
///   - Persisted account rows, typed account lists, balance summaries.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/account_model.dart';
import 'package:sqflite/sqflite.dart';

/// Data access helpers for the `accounts` table.
class AccountRepository {
  /// Returns all connected accounts ordered by type then name.
  static Future<List<AccountModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      orderBy: 'type ASC, name ASC',
    );
    return rows.map((r) => AccountModel.fromMap(r)).toList();
  }

  /// Returns accounts filtered by type.
  static Future<List<AccountModel>> getByType(AccountType type) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'name ASC',
    );
    return rows.map((r) => AccountModel.fromMap(r)).toList();
  }

  /// Returns a single account by Akahu ID.
  static Future<AccountModel?> getByAkahuId(String akahuId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'akahu_id = ?',
      whereArgs: [akahuId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountModel.fromMap(rows.first);
  }

  /// Upserts accounts from Akahu API payload.
  /// Replaces matching rows by `akahu_id`, preserving the user's excluded flag.
  static Future<void> upsertFromAkahu(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await AppDatabase.instance.database;

    // Preserve existing excluded flags before upserting
    final existingRows = await db.query('accounts',
        columns: ['akahu_id', 'excluded']);
    final excludedByAkahuId = <String, int>{};
    for (final row in existingRows) {
      final id = row['akahu_id'] as String?;
      if (id != null) {
        excludedByAkahuId[id] = (row['excluded'] as int?) ?? 0;
      }
    }

    final batch = db.batch();
    for (final item in items) {
      final account = AccountModel.fromAkahu(item);
      final map = account.toDbMap();
      if (excludedByAkahuId.containsKey(account.akahuId)) {
        map['excluded'] = excludedByAkahuId[account.akahuId];
      }
      batch.insert(
        'accounts',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Inserts or updates a single account.
  static Future<int> upsert(AccountModel account) async {
    final db = await AppDatabase.instance.database;
    return await db.insert(
      'accounts',
      account.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes an account by ID.
  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// Toggles whether an account's transactions are excluded from calculations.
  static Future<void> setExcluded({
    required int id,
    required bool excluded,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'accounts',
      {'excluded': excluded ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns counts of budgets and recurring transactions that are meaningfully
  /// linked to this account's transactions. "Meaningful" means the account's
  /// own weekly spend in the budgeted category is >= [minWeekly] (matching the
  /// budget screen's $5 suggestion threshold).
  static Future<({int budgetCount, int recurringCount})>
      getLinkedBudgetAndRecurringCounts(String akahuId, {
    double minWeekly = 5.0,
  }) async {
    final db = await AppDatabase.instance.database;

    // This account's weekly spend per category over the last 30 days
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));
    final startStr = _isoDate(windowStart);
    final endStr = _isoDate(now);
    const weeks = 30 / 7; // ~4.29

    final spendRows = await db.rawQuery('''
      SELECT category_id, ABS(SUM(amount)) AS total
      FROM transactions
      WHERE account_id = ?
        AND type = 'expense'
        AND excluded = 0
        AND date BETWEEN ? AND ?
        AND category_id IS NOT NULL
      GROUP BY category_id
    ''', [akahuId, startStr, endStr]);

    // Category IDs where this account spends >= minWeekly per week
    final significantCatIds = <int>{};
    for (final row in spendRows) {
      final catId = row['category_id'] as int?;
      final total = ((row['total'] as num?) ?? 0).toDouble();
      if (catId != null && total / weeks >= minWeekly) {
        significantCatIds.add(catId);
      }
    }

    // Count budgets linked to those significant categories
    int budgetCount = 0;
    if (significantCatIds.isNotEmpty) {
      final placeholders =
          List.filled(significantCatIds.length, '?').join(',');
      final bRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM budgets '
        'WHERE category_id IN ($placeholders) AND weekly_limit >= ?',
        [...significantCatIds.toList(), minWeekly],
      );
      budgetCount = (bRows.first['c'] as int?) ?? 0;
    }

    // This account's descriptions with significant weekly spend
    final descSpendRows = await db.rawQuery('''
      SELECT LOWER(TRIM(description)) AS desc_key, ABS(SUM(amount)) AS total
      FROM transactions
      WHERE account_id = ?
        AND type = 'expense'
        AND excluded = 0
        AND date BETWEEN ? AND ?
        AND description IS NOT NULL
        AND TRIM(description) <> ''
      GROUP BY desc_key
    ''', [akahuId, startStr, endStr]);

    final significantDescKeys = <String>{};
    for (final row in descSpendRows) {
      final key = (row['desc_key'] as String?) ?? '';
      final total = ((row['total'] as num?) ?? 0).toDouble();
      if (key.isNotEmpty && total / weeks >= minWeekly) {
        significantDescKeys.add(key);
      }
    }

    // Count recurring transactions matching those significant descriptions
    int recurringCount = 0;
    if (significantDescKeys.isNotEmpty) {
      final allRecurring = await db.query('recurring_transactions',
          columns: ['id', 'description', 'amount', 'frequency']);
      for (final row in allRecurring) {
        final desc = (row['description'] as String?) ?? '';
        if (!significantDescKeys.contains(desc.toLowerCase().trim())) continue;
        final amount = ((row['amount'] as num?) ?? 0).toDouble().abs();
        final freq = ((row['frequency'] as String?) ?? '').toLowerCase();
        final weekly = freq == 'monthly' ? amount / 4.345 : amount;
        if (weekly >= minWeekly) recurringCount++;
      }
    }

    return (budgetCount: budgetCount, recurringCount: recurringCount);
  }

  static String _isoDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Removes all accounts. Used during bank disconnect.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('accounts');
  }

  // ---------------------------------------------------------------------------
  // Aggregation helpers for balance sheet
  // ---------------------------------------------------------------------------

  /// Returns the sum of all asset account balances (checking, savings, investments).
  /// Excludes accounts the user has deselected.
  static Future<double> getTotalAssets() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type NOT IN ('creditCard', 'loan')
        AND balance_current > 0
        AND excluded = 0
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns the sum of all liability balances (credit cards, loans).
  /// Returns as positive number (amount owed).
  /// Excludes accounts the user has deselected.
  static Future<double> getTotalLiabilities() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(ABS(balance_current)) as total
      FROM accounts
      WHERE excluded = 0
        AND (type IN ('creditCard', 'loan') OR balance_current < 0)
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns net worth (assets minus liabilities).
  /// Excludes accounts the user has deselected.
  static Future<double> getNetWorth() async {
    final accounts = await getAll();
    double netWorth = 0.0;
    for (final account in accounts) {
      if (!account.excluded) {
        netWorth += account.netWorthContribution;
      }
    }
    return netWorth;
  }

  /// Returns total balance across all savings-type accounts.
  /// Excludes accounts the user has deselected.
  static Future<double> getTotalSavings() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type = 'savings'
        AND excluded = 0
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns total balance across all checking/everyday accounts.
  /// Excludes accounts the user has deselected.
  static Future<double> getTotalChecking() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type = 'checking'
        AND excluded = 0
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns accounts grouped by connection (bank).
  static Future<Map<String, List<AccountModel>>> getGroupedByConnection() async {
    final accounts = await getAll();
    final grouped = <String, List<AccountModel>>{};
    for (final account in accounts) {
      final key = account.connectionName ?? 'Other';
      grouped.putIfAbsent(key, () => []).add(account);
    }
    return grouped;
  }

  /// Returns a summary map for quick dashboard display.
  /// Excludes accounts the user has deselected.
  static Future<Map<String, dynamic>> getBalanceSummary() async {
    final accounts = await getAll();
    
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    double totalSavings = 0.0;
    double totalChecking = 0.0;
    double totalInvestments = 0.0;
    
    for (final account in accounts) {
      if (account.excluded) continue;
      if (account.type.isLiability) {
        totalLiabilities += account.balanceCurrent.abs();
      } else {
        totalAssets += account.balanceCurrent;
        
        switch (account.type) {
          case AccountType.savings:
            totalSavings += account.balanceCurrent;
            break;
          case AccountType.checking:
            totalChecking += account.balanceCurrent;
            break;
          case AccountType.kiwiSaver:
          case AccountType.investment:
            totalInvestments += account.balanceCurrent;
            break;
          default:
            break;
        }
      }
    }
    
    return {
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'netWorth': totalAssets - totalLiabilities,
      'totalSavings': totalSavings,
      'totalChecking': totalChecking,
      'totalInvestments': totalInvestments,
      'accountCount': accounts.length,
    };
  }
}
