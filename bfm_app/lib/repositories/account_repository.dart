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
  /// Replaces matching rows by `akahu_id`.
  static Future<void> upsertFromAkahu(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();

    for (final item in items) {
      final account = AccountModel.fromAkahu(item);
      batch.insert(
        'accounts',
        account.toDbMap(),
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

  /// Removes all accounts. Used during bank disconnect.
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('accounts');
  }

  // ---------------------------------------------------------------------------
  // Aggregation helpers for balance sheet
  // ---------------------------------------------------------------------------

  /// Returns the sum of all asset account balances (checking, savings, investments).
  static Future<double> getTotalAssets() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type NOT IN ('creditCard', 'loan')
        AND balance_current > 0
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns the sum of all liability balances (credit cards, loans).
  /// Returns as positive number (amount owed).
  static Future<double> getTotalLiabilities() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(ABS(balance_current)) as total
      FROM accounts
      WHERE type IN ('creditCard', 'loan')
        OR balance_current < 0
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns net worth (assets minus liabilities).
  static Future<double> getNetWorth() async {
    final accounts = await getAll();
    double netWorth = 0.0;
    for (final account in accounts) {
      netWorth += account.netWorthContribution;
    }
    return netWorth;
  }

  /// Returns total balance across all savings-type accounts.
  static Future<double> getTotalSavings() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type = 'savings'
    ''');
    final value = rows.isNotEmpty ? rows.first['total'] : null;
    return (value is num) ? value.toDouble() : 0.0;
  }

  /// Returns total balance across all checking/everyday accounts.
  static Future<double> getTotalChecking() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT SUM(balance_current) as total
      FROM accounts
      WHERE type = 'checking'
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
  static Future<Map<String, dynamic>> getBalanceSummary() async {
    final accounts = await getAll();
    
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    double totalSavings = 0.0;
    double totalChecking = 0.0;
    double totalInvestments = 0.0;
    
    for (final account in accounts) {
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
