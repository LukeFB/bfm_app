// -----------------------------------------------------------------------------
// Author: Luke Fraser-Brown
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
      version: 13,
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

    // Ensure base tables exist
    if (!await hasTable('categories')) await _createCategories(db);
    if (!await hasTable('transactions')) await _createTransactions(db);
    if (!await hasTable('goals')) await _createGoals(db);
    if (!await hasTable('budgets')) await _createBudgets(db);
    if (!await hasTable('recurring_transactions')) await _createRecurring(db);
    if (!await hasTable('alerts')) await _createAlerts(db);
    if (!await hasTable('events')) {
      await _createEvents(db);
    } else {
      final hasTitleOnEvents = await hasCol('events', 'title');
      if (!hasTitleOnEvents) {
        await _recreateEventsTable(db);
      }
    }
    if (!await hasTable('referrals')) await _createReferrals(db);
    if (!await hasTable('tips')) await _createTips(db);
    if (!await hasTable('goal_progress_log')) await _createGoalProgressLog(db);
    if (!await hasTable('weekly_reports')) await _createWeeklyReports(db);

    // Goals schema migration (name, amount, weekly_contribution, saved_amount)
    final hasGoalName = await hasCol('goals', 'name');
    final hasGoalAmount = await hasCol('goals', 'amount');
    final hasGoalWeekly = await hasCol('goals', 'weekly_contribution');
    if (!(hasGoalName && hasGoalAmount && hasGoalWeekly)) {
      await _recreateGoalsTable(db);
    }
    if (!await hasCol('goals', 'saved_amount')) {
      await db.execute(
        'ALTER TABLE goals ADD COLUMN saved_amount REAL NOT NULL DEFAULT 0;',
      );
    }

    // Budgets schema migration (nullable category_id + goal linkage)
    final hasGoalIdOnBudgets = await hasCol('budgets', 'goal_id');
    if (!hasGoalIdOnBudgets) {
      await _recreateBudgetsTable(db);
    }
    if (!await hasCol('budgets', 'label')) {
      await db.execute('ALTER TABLE budgets ADD COLUMN label TEXT;');
    }

    await _createGoalProgressLog(db);

    // ---- transaction columns ----
    if (!await hasCol('transactions', 'akahu_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN akahu_id TEXT;');
    }
    if (!await hasCol('transactions', 'account_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN account_id TEXT;');
    }
    if (!await hasCol('transactions', 'connection_id')) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN connection_id TEXT;',
      );
    }
    if (!await hasCol('transactions', 'merchant_name')) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN merchant_name TEXT;',
      );
    }
    if (!await hasCol('transactions', 'category_name')) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN category_name TEXT;',
      );
    }
    if (!await hasCol('transactions', 'category_id')) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN category_id INTEGER;',
      );
    }
    if (!await hasCol('transactions', 'akahu_hash')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN akahu_hash TEXT;');
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_transactions_akahu_hash ON transactions(akahu_hash) WHERE akahu_hash IS NOT NULL;',
    );

    // ---- category columns ----
    if (!await hasCol('categories', 'akahu_category_id')) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN akahu_category_id TEXT;',
      );
    }
    if (!await hasCol('categories', 'usage_count')) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (!await hasCol('categories', 'first_seen_at')) {
      await db.execute('ALTER TABLE categories ADD COLUMN first_seen_at TEXT;');
    }
    if (!await hasCol('categories', 'last_used_at')) {
      await db.execute('ALTER TABLE categories ADD COLUMN last_used_at TEXT;');
    }

    // Recreate helpful indexes & triggers for category usage tracking
    await _ensureIndexesAndTriggers(db);

    // Backfill usage_count from existing transactions
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
    await _createReferrals(db);
    await _createTips(db);
    await _createGoalProgressLog(db);
    await _createWeeklyReports(db);
    await _ensureIndexesAndTriggers(db);
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
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_categories_name ON categories(name COLLATE NOCASE);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_categories_usage ON categories(usage_count DESC);',
    );
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
        akahu_hash TEXT,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_transactions_date ON transactions(date DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_transactions_category_id ON transactions(category_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_transactions_type ON transactions(type);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_transactions_akahu_hash ON transactions(akahu_hash) WHERE akahu_hash IS NOT NULL;',
    );
  }

  Future<void> _createGoals(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        weekly_contribution REAL NOT NULL DEFAULT 0,
        saved_amount REAL NOT NULL DEFAULT 0
      );
    ''');
  }

  Future<void> _recreateGoalsTable(Database db) async {
    await db.execute('ALTER TABLE goals RENAME TO goals_old;');
    await _createGoals(db);
    await db.execute(r'''
      INSERT INTO goals (id, name, amount, weekly_contribution, saved_amount)
      SELECT
        id,
        COALESCE(title, 'Goal'),
        COALESCE(target_amount, 0),
        0.0,
        0.0
      FROM goals_old;
    ''');
    await db.execute('DROP TABLE goals_old;');
  }

  Future<void> _createBudgets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        goal_id INTEGER,
        label TEXT,
        weekly_limit REAL NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id),
        FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_budgets_category_id ON budgets(category_id);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_budgets_goal_id ON budgets(goal_id) WHERE goal_id IS NOT NULL;',
    );
  }

  Future<void> _recreateBudgetsTable(Database db) async {
    await db.execute('ALTER TABLE budgets RENAME TO budgets_old;');
    await _createBudgets(db);
    await db.execute(r'''
      INSERT INTO budgets (
        id,
        category_id,
        label,
        weekly_limit,
        period_start,
        period_end,
        created_at,
        updated_at
      )
      SELECT
        id,
        category_id,
        NULL,
        weekly_limit,
        period_start,
        period_end,
        created_at,
        updated_at
      FROM budgets_old;
    ''');
    await db.execute('DROP TABLE budgets_old;');
  }

  Future<void> _createGoalProgressLog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_progress_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        week_start TEXT NOT NULL,
        status TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE,
        UNIQUE(goal_id, week_start)
      );
    ''');
  }

  Future<void> _createWeeklyReports(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_start TEXT NOT NULL UNIQUE,
        week_end TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');
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
        backend_id INTEGER,
        title TEXT NOT NULL,
        description TEXT,
        location TEXT,
        region TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        registration_url TEXT,
        icon TEXT,
        audience TEXT,
        is_virtual INTEGER NOT NULL DEFAULT 0,
        is_published INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_events_backend ON events(backend_id) WHERE backend_id IS NOT NULL;',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_events_start_date ON events(start_date);',
    );
  }

  Future<void> _recreateEventsTable(Database db) async {
    await db.execute('ALTER TABLE events RENAME TO events_old;');
    await _createEvents(db);
    await db.execute('''
      INSERT INTO events (
        backend_id,
        title,
        description,
        start_date,
        icon,
        is_virtual,
        is_published,
        updated_at,
        synced_at
      )
      SELECT
        NULL,
        text,
        NULL,
        datetime('now'),
        icon,
        0,
        1,
        datetime('now'),
        datetime('now')
      FROM events_old;
    ''');
    await db.execute('DROP TABLE events_old;');
  }

  Future<void> _createReferrals(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS referrals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backend_id INTEGER,
        organisation_name TEXT,
        category TEXT,
        website TEXT,
        phone TEXT,
        services TEXT,
        demographics TEXT,
        availability TEXT,
        email TEXT,
        address TEXT,
        region TEXT,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_referrals_backend ON referrals(backend_id) WHERE backend_id IS NOT NULL;',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_referrals_updated ON referrals(updated_at DESC);',
    );
  }

  Future<void> _createTips(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backend_id INTEGER,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT,
        audience TEXT,
        cta_label TEXT,
        cta_url TEXT,
        priority INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        publish_at TEXT,
        expires_at TEXT,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_tips_backend ON tips(backend_id) WHERE backend_id IS NOT NULL;',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_tips_priority ON tips(priority DESC, updated_at DESC);',
    );
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
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }
}
