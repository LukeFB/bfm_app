/// ---------------------------------------------------------------------------
/// File: lib/services/savings_service.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `savings_screen.dart` for loading balance sheet and account data.
///
/// Purpose:
///   - Orchestrates account data fetching and aggregation for the savings view.
///   - Calculates profit/loss metrics from transaction history.
///   - Aggregates user-entered assets for net worth display.
///
/// Inputs:
///   - Account repository, transaction repository, asset repository.
///
/// Outputs:
///   - `SavingsData` bundle with all metrics needed for the UI.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/models/account_model.dart';
import 'package:bfm_app/models/asset_model.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/asset_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';

/// Time frame options for profit/loss calculation.
enum ProfitLossTimeFrame {
  thisWeek,
  thisMonth,
  last3Months,
  last6Months,
  thisYear,
  allTime;

  /// Returns the display label for the dropdown.
  String get label {
    switch (this) {
      case ProfitLossTimeFrame.thisWeek:
        return 'This Week';
      case ProfitLossTimeFrame.thisMonth:
        return 'This Month';
      case ProfitLossTimeFrame.last3Months:
        return 'Last 3 Months';
      case ProfitLossTimeFrame.last6Months:
        return 'Last 6 Months';
      case ProfitLossTimeFrame.thisYear:
        return 'This Year';
      case ProfitLossTimeFrame.allTime:
        return 'All Time';
    }
  }

  /// Returns the start date for this time frame.
  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case ProfitLossTimeFrame.thisWeek:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case ProfitLossTimeFrame.thisMonth:
        return DateTime(now.year, now.month, 1);
      case ProfitLossTimeFrame.last3Months:
        return DateTime(now.year, now.month - 2, 1);
      case ProfitLossTimeFrame.last6Months:
        return DateTime(now.year, now.month - 5, 1);
      case ProfitLossTimeFrame.thisYear:
        return DateTime(now.year, 1, 1);
      case ProfitLossTimeFrame.allTime:
        return DateTime(2000, 1, 1);
    }
  }

  /// Parses from stored string value.
  static ProfitLossTimeFrame fromString(String? value) {
    if (value == null) return ProfitLossTimeFrame.allTime;
    return ProfitLossTimeFrame.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProfitLossTimeFrame.allTime,
    );
  }
}

/// Aggregated data for the savings screen.
class SavingsData {
  /// Total income from all transactions.
  final double totalIncome;

  /// Total expenses from all transactions.
  final double totalExpenses;

  /// Overall profit/loss (income - expenses).
  final double overallProfitLoss;

  /// All connected accounts.
  final List<AccountModel> accounts;

  /// Accounts grouped by bank/connection.
  final Map<String, List<AccountModel>> accountsByBank;

  /// User-entered assets.
  final List<AssetModel> assets;

  /// Assets grouped by category.
  final Map<AssetCategory, List<AssetModel>> assetsByCategory;

  /// Total value of all assets.
  final double totalAssetValue;

  const SavingsData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.overallProfitLoss,
    required this.accounts,
    required this.accountsByBank,
    required this.assets,
    required this.assetsByCategory,
    required this.totalAssetValue,
  });
}

/// Service for loading and calculating savings/balance sheet data.
class SavingsService {
  /// Loads all data needed for the savings screen.
  /// [timeFrame] controls the date range for profit/loss calculation.
  static Future<SavingsData> loadSavingsData({
    ProfitLossTimeFrame timeFrame = ProfitLossTimeFrame.allTime,
  }) async {
    final now = DateTime.now();
    final startDate = timeFrame.startDate;

    // Fetch all data in parallel
    final results = await Future.wait([
      AccountRepository.getAll(),
      AccountRepository.getGroupedByConnection(),
      TransactionRepository.sumIncomeBetween(startDate, now),
      _sumExpensesBetween(startDate, now),
      AssetRepository.getAll(),
      AssetRepository.getGroupedByCategory(),
      AssetRepository.getTotalValue(),
    ]);

    final accounts = results[0] as List<AccountModel>;
    final accountsByBank = results[1] as Map<String, List<AccountModel>>;
    final totalIncome = results[2] as double;
    final totalExpenses = results[3] as double;
    final assets = results[4] as List<AssetModel>;
    final assetsByCategory = results[5] as Map<AssetCategory, List<AssetModel>>;
    final totalAssetValue = results[6] as double;

    return SavingsData(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      overallProfitLoss: totalIncome - totalExpenses,
      accounts: accounts,
      accountsByBank: accountsByBank,
      assets: assets,
      assetsByCategory: assetsByCategory,
      totalAssetValue: totalAssetValue,
    );
  }

  /// Sums expenses between dates (excludes transfers).
  static Future<double> _sumExpensesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final byCategory = await TransactionRepository.sumExpensesByCategoryBetween(
      start,
      end,
    );
    double total = 0.0;
    for (final amount in byCategory.values) {
      total += amount;
    }
    return total;
  }

  /// Gets profit/loss for a specific date range.
  static Future<double> getProfitLoss(DateTime start, DateTime end) async {
    final income = await TransactionRepository.sumIncomeBetween(start, end);
    final expensesByCategory =
        await TransactionRepository.sumExpensesByCategoryBetween(start, end);
    double expenses = 0.0;
    for (final amount in expensesByCategory.values) {
      expenses += amount;
    }
    return income - expenses;
  }

  /// Gets profit/loss for the current week.
  static Future<double> getProfitLossThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return getProfitLoss(startOfWeek, now);
  }

  /// Gets profit/loss for the current month.
  static Future<double> getProfitLossThisMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return getProfitLoss(startOfMonth, now);
  }
}
