// Fully commented.
// Central place to load all dashboard data from the database in one go.
// This keeps your UI clean and unchanged.

import 'package:collection/collection.dart';
import '../db/database.dart';

/// A single object containing all data your dashboard shows,
/// so your UI can remain exactly the same and just read fields.
class DashboardSnapshot {
  // Top summary
  final double balance;
  final double totalIncome;
  final double totalExpenses;

  // Goals
  final List<GoalModel> goals;

  // Category totals (expense aggregation)
  final Map<String, double> categoryTotals;

  // Recent transactions
  final List<TransactionModel> recentTransactions;

  // Weekly budget master (sum over categories)
  final double totalWeeklyBudget;

  // Optional: per-category left-to-spend for the current week
  final Map<int, double> leftToSpendByCategory;

  // Monthly summary (derived) for current month
  final double monthBudget;
  final double monthSpent;
  final double monthLeft;

  DashboardSnapshot({
    required this.balance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.goals,
    required this.categoryTotals,
    required this.recentTransactions,
    required this.totalWeeklyBudget,
    required this.leftToSpendByCategory,
    required this.monthBudget,
    required this.monthSpent,
    required this.monthLeft,
  });
}

/// Repository that knows how to query the DB and assemble a full dashboard snapshot.
class DashboardRepository {
  /// Load everything the dashboard needs in parallel.
  static Future<DashboardSnapshot> load({int recentLimit = 5}) async {
    // Run independent queries concurrently for speed.
    final futures = await Future.wait([
      _getBalanceParts(),                 // 0: income, expenses, balance
      getGoals(),                         // 1: goals
      getCategoryTotals(),                // 2: category expense totals
      getRecentTransactions(recentLimit), // 3: recent transactions
      getTotalWeeklyBudget(),             // 4: total weekly budget
      _getLeftToSpendAllCategories(),     // 5: left-to-spend per category (current week)
      _getCurrentMonthSummary(),          // 6: month budget/spent/left
    ]);

    final incomeExpenseBalance = futures[0] as _BalanceParts;
    final goals = futures[1] as List<GoalModel>;
    final categoryTotals = futures[2] as Map<String, double>;
    final recent = futures[3] as List<TransactionModel>;
    final weeklyTotal = futures[4] as double;
    final leftToSpend = futures[5] as Map<int, double>;
    final month = futures[6] as _MonthSummary;

    return DashboardSnapshot(
      balance: incomeExpenseBalance.balance,
      totalIncome: incomeExpenseBalance.income,
      totalExpenses: incomeExpenseBalance.expenses,
      goals: goals,
      categoryTotals: categoryTotals,
      recentTransactions: recent,
      totalWeeklyBudget: weeklyTotal,
      leftToSpendByCategory: leftToSpend,
      monthBudget: month.budget,
      monthSpent: month.spent,
      monthLeft: month.left,
    );
  }

  /// Get income, expenses, and balance separately, so you can show the same UI labels/colors.
  static Future<_BalanceParts> _getBalanceParts() async {
    final db = await AppDatabase.instance.database;

    final incRes = await db.rawQuery(
      "SELECT IFNULL(SUM(amount),0) AS income FROM transactions WHERE type = 'income';"
    );
    final expRes = await db.rawQuery(
      "SELECT IFNULL(SUM(amount),0) AS expense FROM transactions WHERE type = 'expense';"
    );

    final income = (incRes.first['income'] as num).toDouble();
    final expenses = (expRes.first['expense'] as num).toDouble().abs();
    final balance = income - expenses;

    return _BalanceParts(income: income, expenses: expenses, balance: balance);
  }

  /// For each category that has a weekly budget row, compute its left-to-spend this week.
  static Future<Map<int, double>> _getLeftToSpendAllCategories() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('budgets', columns: ['category_id']);
    final ids = rows
        .map((r) => r['category_id'])
        .whereNotNull()
        .map((e) => e as int)
        .toSet()
        .toList();

    final Map<int, double> out = {};
    for (final categoryId in ids) {
      out[categoryId] = await getLeftToSpend(categoryId);
    }
    return out;
  }

  /// Current month summary using the helper you already have.
  static Future<_MonthSummary> _getCurrentMonthSummary() async {
    final now = DateTime.now();
    final m = await getMonthlySummary(now.year, now.month);
    return _MonthSummary(
      budget: (m['budget'] as num).toDouble(),
      spent: (m['spent'] as num).toDouble(),
      left: (m['left'] as num).toDouble(),
    );
  }
}

/// Internal struct to carry income/expense/balance parts.
class _BalanceParts {
  final double income;
  final double expenses;
  final double balance;
  _BalanceParts({
    required this.income,
    required this.expenses,
    required this.balance,
  });
}

/// Internal struct for month summary.
class _MonthSummary {
  final double budget;
  final double spent;
  final double left;
  _MonthSummary({required this.budget, required this.spent, required this.left});
}
