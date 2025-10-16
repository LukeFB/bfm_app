// -----------------------------------------------------------------------------
// Author: Luke Fraser-Brown & Jack Unsworth
// -----------------------------------------------------------------------------

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

    // Open the database with version and an onUpgrade callback
    return await openDatabase(
      path,
      version: 6, 
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Define the onUpgrade to alter tables for new columns
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    Future<bool> hasTable(String table) async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      return rows.isNotEmpty;
    }

    Future<bool> hasCol(String table, String col) async {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any(
        (r) => (r['name'] as String).toLowerCase() == col.toLowerCase(),
      );
    }

    // Ensure base tables exist (defensive)
    if (!await hasTable('categories')) await _createCategories(db);
    if (!await hasTable('transactions')) await _createTransactions(db);
    if (!await hasTable('goals')) await _createGoals(db);
    if (!await hasTable('budgets')) await _createBudgets(db);
    if (!await hasTable('recurring_transactions')) await _createRecurring(db);
    if (!await hasTable('alerts')) await _createAlerts(db);
    if (!await hasTable('events')) await _createEvents(db);

    // ---- transactions incremental columns (idempotent) ----
    if (!await hasCol('transactions', 'akahu_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN akahu_id TEXT;');
    }
    if (!await hasCol('transactions', 'account_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN account_id TEXT;');
    }
    if (!await hasCol('transactions', 'connection_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN connection_id TEXT;');
    }
    if (!await hasCol('transactions', 'merchant_name')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN merchant_name TEXT;');
    }
    if (!await hasCol('transactions', 'category_name')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN category_name TEXT;');
    }
    if (!await hasCol('transactions', 'category_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN category_id INTEGER;');
    }

    // ---- categories incremental columns (this fixes your error) ----
    if (!await hasCol('categories', 'akahu_category_id')) {
      await db.execute('ALTER TABLE categories ADD COLUMN akahu_category_id TEXT;');
    }
    if (!await hasCol('categories', 'usage_count')) {
      await db.execute('ALTER TABLE categories ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0;');
    }
    if (!await hasCol('categories', 'first_seen_at')) {
      await db.execute('ALTER TABLE categories ADD COLUMN first_seen_at TEXT;');
    }
    if (!await hasCol('categories', 'last_used_at')) {
      await db.execute('ALTER TABLE categories ADD COLUMN last_used_at TEXT;');
    }

    // Recreate helpful indexes & triggers
    await _ensureIndexesAndTriggers(db);

    // Ensure "Uncategorized" exists
    await db.rawInsert('''
      INSERT INTO categories (name, icon, color, first_seen_at, last_used_at)
      SELECT 'Uncategorized', '❓', '#CCCCCC', datetime('now'), datetime('now')
      WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name COLLATE NOCASE = 'uncategorized');
    ''');

    // Backfill usage_count from existing transactions (once)
    await db.rawUpdate('''
      UPDATE categories
      SET usage_count = (
        SELECT COUNT(*) FROM transactions t WHERE t.category_id = categories.id
      );
    ''');
  }

  /// Database schema
  Future _createDB(Database db, int version) async {
    await _createCategories(db);
    await _createTransactions(db);
    await _createGoals(db);
    await _createBudgets(db);
    await _createRecurring(db);
    await _createAlerts(db);
    await _createEvents(db);
    await _ensureIndexesAndTriggers(db);

    // Seed "Uncategorized"
    await db.rawInsert('''
      INSERT INTO categories (name, icon, color, first_seen_at, last_used_at)
      VALUES ('Uncategorized', '❓', '#CCCCCC', datetime('now'), datetime('now'));
    ''');
  }

  // --- DDL helpers ---

  Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        akahu_category_id TEXT,
        usage_count INTEGER NOT NULL DEFAULT 0,
        first_seen_at TEXT,
        last_used_at TEXT
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS ux_categories_name ON categories(name COLLATE NOCASE);');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_categories_usage ON categories(usage_count DESC);');
  }

  Future<void> _createTransactions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        akahu_id TEXT,
        account_id TEXT,
        connection_id TEXT,
        merchant_name TEXT,
        category_name TEXT,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_transactions_date ON transactions(date DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_transactions_category_id ON transactions(category_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_transactions_type ON transactions(type);');
  }

  Future<void> _createGoals(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL DEFAULT 0,
        due_date TEXT,
        status TEXT DEFAULT 'active'
      );
    ''');
  }

  Future<void> _createBudgets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        weekly_limit REAL NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_budgets_category_id ON budgets(category_id);');
  }

  Future<void> _createRecurring(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
  }

  Future<void> _createAlerts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        icon TEXT
      );
    ''');
  }

  Future<void> _createEvents(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        icon TEXT
      );
    ''');
  }

  Future<void> _ensureIndexesAndTriggers(Database db) async {
    // usage_count triggers
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_txn_insert_category_usage
      AFTER INSERT ON transactions
      WHEN NEW.category_id IS NOT NULL
      BEGIN
        UPDATE categories
          SET usage_count = usage_count + 1,
              last_used_at = datetime('now')
        WHERE id = NEW.category_id;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_txn_delete_category_usage
      AFTER DELETE ON transactions
      WHEN OLD.category_id IS NOT NULL
      BEGIN
        UPDATE categories
          SET usage_count = CASE WHEN usage_count > 0 THEN usage_count - 1 ELSE 0 END,
              last_used_at = datetime('now')
        WHERE id = OLD.category_id;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_txn_update_category_usage
      AFTER UPDATE OF category_id ON transactions
      BEGIN
        UPDATE categories
          SET usage_count = CASE WHEN usage_count > 0 THEN usage_count - 1 ELSE 0 END,
              last_used_at = datetime('now')
        WHERE id = OLD.category_id AND OLD.category_id IS NOT NULL;

        UPDATE categories
          SET usage_count = usage_count + 1,
              last_used_at = datetime('now')
        WHERE id = NEW.category_id AND NEW.category_id IS NOT NULL;
      END;
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
