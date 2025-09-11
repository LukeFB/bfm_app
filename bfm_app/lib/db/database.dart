import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper for app database
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("bfm_app.db");
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Database schema
  Future _createDB(Database db, int version) async {
    // --- Categories ---
    // Examples: Food, Rent, Bills, Transport, Entertainment, Unknown
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT
      );
    ''');

    // --- Transactions (bank data) ---
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,   -- YYYY-MM-DD
        type TEXT NOT NULL,   -- 'income' or 'expense'
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');

    // --- Goals (savings targets) ---
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL DEFAULT 0,
        due_date TEXT,
        status TEXT DEFAULT 'active'
      );
    ''');

    // --- Budgets (weekly = master) ---
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        weekly_limit REAL NOT NULL,
        period_start TEXT NOT NULL, -- YYYY-MM-DD (week start)
        period_end TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');

    // --- Recurring Bills (expected, not inserted into transactions) ---
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,   -- 'weekly' or 'monthly'
        next_due_date TEXT NOT NULL, -- YYYY-MM-DD
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

//
// ------------------ MODELS ------------------
//

class TransactionModel {
  final int? id;
  final int? categoryId;
  final double amount;
  final String description;
  final String date;
  final String type;

  TransactionModel({
    this.id,
    this.categoryId,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      description: map['description'] ?? '',
      date: map['date'],
      type: map['type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'date': date,
      'type': type,
    };
  }
}

class GoalModel {
  final int? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? dueDate;
  final String status;

  GoalModel({
    this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    this.dueDate,
    this.status = 'active',
  });

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'],
      title: map['title'],
      targetAmount: map['target_amount'],
      currentAmount: map['current_amount'],
      dueDate: map['due_date'],
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'due_date': dueDate,
      'status': status,
    };
  }
}

class BudgetModel {
  final int? id;
  final int categoryId;
  final double weeklyLimit;
  final String periodStart;
  final String? periodEnd;

  BudgetModel({
    this.id,
    required this.categoryId,
    required this.weeklyLimit,
    required this.periodStart,
    this.periodEnd,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'],
      categoryId: map['category_id'],
      weeklyLimit: map['weekly_limit'],
      periodStart: map['period_start'],
      periodEnd: map['period_end'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'weekly_limit': weeklyLimit,
      'period_start': periodStart,
      'period_end': periodEnd,
    };
  }
}

class RecurringModel {
  final int? id;
  final int categoryId;
  final double amount;
  final String frequency; // weekly or monthly
  final String nextDueDate;
  final String? description;

  RecurringModel({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    this.description,
  });

  factory RecurringModel.fromMap(Map<String, dynamic> map) {
    return RecurringModel(
      id: map['id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      frequency: map['frequency'],
      nextDueDate: map['next_due_date'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency,
      'next_due_date': nextDueDate,
      'description': description,
    };
  }
}

//
// ------------------ QUERIES ------------------
//

/// TRANSACTIONS
Future<int> insertTransaction(TransactionModel txn) async {
  final db = await AppDatabase.instance.database;
  return await db.insert('transactions', txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<TransactionModel>> getRecentTransactions(int limit) async {
  final db = await AppDatabase.instance.database;
  final result = await db.query('transactions',
      orderBy: 'date DESC', limit: limit);
  return result.map((e) => TransactionModel.fromMap(e)).toList();
}

/// Get all transactions (optionally filtered by category)
Future<List<TransactionModel>> getAllTransactions({int? categoryId}) async {
  final db = await AppDatabase.instance.database;
  List<Map<String, dynamic>> result;

  if (categoryId != null) {
    result = await db.query(
      'transactions',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
  } else {
    result = await db.query('transactions', orderBy: 'date DESC');
  }

  return result.map((e) => TransactionModel.fromMap(e)).toList();
}

/// Delete a transaction by ID
Future<int> deleteTransaction(int id) async {
  final db = await AppDatabase.instance.database;
  return await db.delete(
    'transactions',
    where: 'id = ?',
    whereArgs: [id],
  );
}


/// BALANCE = income – expenses
Future<double> getBalance() async {
  final db = await AppDatabase.instance.database;
  final result = await db.rawQuery('''
    SELECT 
      (SELECT IFNULL(SUM(amount), 0) FROM transactions WHERE type = 'income') -
      (SELECT IFNULL(SUM(amount), 0) FROM transactions WHERE type = 'expense')
      AS balance
  ''');
  return result.first['balance'] != null
      ? result.first['balance'] as double
      : 0.0;
}

/// Category totals (expenses grouped by category)
Future<Map<String, double>> getCategoryTotals() async {
  final db = await AppDatabase.instance.database;
  final result = await db.rawQuery('''
    SELECT c.name as category, SUM(t.amount) as total
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.type = 'expense'
    GROUP BY c.name
  ''');

  Map<String, double> totals = {};
  for (var row in result) {
    totals[row['category'] as String] =
        row['total'] != null ? (row['total'] as num).toDouble().abs() : 0.0;
  }
  return totals;
}

/// GOALS
Future<int> insertGoal(GoalModel goal) async {
  final db = await AppDatabase.instance.database;
  return await db.insert('goals', goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<GoalModel>> getGoals() async {
  final db = await AppDatabase.instance.database;
  final result = await db.query('goals');
  return result.map((e) => GoalModel.fromMap(e)).toList();
}

/// Update a goal by ID
Future<int> updateGoal(int id, Map<String, dynamic> values) async {
  final db = await AppDatabase.instance.database;
  return await db.update(
    'goals',
    values,
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// Delete a goal by ID
Future<int> deleteGoal(int id) async {
  final db = await AppDatabase.instance.database;
  return await db.delete(
    'goals',
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// BUDGETS
Future<int> insertBudget(BudgetModel budget) async {
  final db = await AppDatabase.instance.database;
  return await db.insert('budgets', budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<BudgetModel>> getBudgets() async {
  final db = await AppDatabase.instance.database;
  final result = await db.query('budgets');
  return result.map((e) => BudgetModel.fromMap(e)).toList();
}

Future<double> getTotalWeeklyBudget() async {
  final db = await AppDatabase.instance.database;
  final result =
      await db.rawQuery('SELECT SUM(weekly_limit) as total FROM budgets');
  return result.first['total'] != null ? result.first['total'] as double : 0.0;
}

/// Calculate "left to spend" for current week by category
Future<double> getLeftToSpend(int categoryId) async {
  final db = await AppDatabase.instance.database;

  // Get weekly limit
  final limitResult = await db.query('budgets',
      columns: ['weekly_limit'],
      where: 'category_id = ?',
      whereArgs: [categoryId]);

  if (limitResult.isEmpty) return 0.0;
  double weeklyLimit = limitResult.first['weekly_limit'] as double;

  // Start & end of current week (Monday–Sunday)
  DateTime now = DateTime.now();
  DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  String start = startOfWeek.toIso8601String().substring(0, 10);
  String end = now.toIso8601String().substring(0, 10);

  // Total spent this week
  final spentResult = await db.rawQuery('''
    SELECT SUM(amount) as spent
    FROM transactions
    WHERE category_id = ?
      AND type = 'expense'
      AND date BETWEEN ? AND ?
  ''', [categoryId, start, end]);

  double spent = spentResult.first['spent'] != null
      ? (spentResult.first['spent'] as double).abs()
      : 0.0;

  return weeklyLimit - spent;
}

/// MONTHLY SUMMARY (derived from weekly + transactions)
Future<Map<String, dynamic>> getMonthlySummary(int year, int month) async {
  final db = await AppDatabase.instance.database;

  String start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
  String end = DateTime(year, month + 1, 1).toIso8601String().substring(0, 10);

  // Monthly spend
  final spentResult = await db.rawQuery('''
    SELECT SUM(amount) as spent
    FROM transactions
    WHERE type = 'expense'
      AND date BETWEEN ? AND ?
  ''', [start, end]);

  double spent = spentResult.first['spent'] != null
      ? (spentResult.first['spent'] as double).abs()
      : 0.0;

  // Monthly budget = sum of weekly budgets overlapping this month
  final budgetResult = await db.rawQuery('''
    SELECT SUM(weekly_limit) as budget
    FROM budgets
    WHERE date(period_start) BETWEEN ? AND ?
       OR date(period_end) BETWEEN ? AND ?
  ''', [start, end, start, end]);

  double budget = budgetResult.first['budget'] != null
      ? budgetResult.first['budget'] as double
      : 0.0;

  return {"budget": budget, "spent": spent, "left": budget - spent};
}

/// RECURRING BILLS
Future<int> insertRecurring(RecurringModel bill) async {
  final db = await AppDatabase.instance.database;
  return await db.insert('recurring_transactions', bill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<RecurringModel>> getRecurring() async {
  final db = await AppDatabase.instance.database;
  final result = await db.query('recurring_transactions');
  return result.map((e) => RecurringModel.fromMap(e)).toList();
}
