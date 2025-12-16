/// ---------------------------------------------------------------------------
/// File: lib/screens/debug_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/debug` route surfaced from settings.
///
/// Purpose:
///   - Developer-only dump of prefs, DB metadata, budgets, categories, and
///     transaction stats to help diagnose local issues.
///
/// Inputs:
///   - Reads from `SharedPreferences`, SQLite, and repositories.
///
/// Outputs:
///   - Plain-text diagnostic report rendered in a scrollable view.
/// ---------------------------------------------------------------------------
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';

/// Developer panel that prints diagnostics to the screen.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

/// Loads diagnostic info and renders it as monospaced text.
class _DebugScreenState extends State<DebugScreen> {
  String _text = 'Loading…';

  /// Boots the diagnostics fetch.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Formats byte counts into KB/MB strings.
  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(2)} ${units[unit]}';
  }

  /// Builds the entire debug report and surfaces warnings.
  Future<void> _load() async {
    final buf = StringBuffer();

    // ---------- App / Device ----------
    final info = await PackageInfo.fromPlatform();
    final os = Platform.operatingSystem;
    final osVer = Platform.operatingSystemVersion;
    buf.writeln('==================== BFM DEBUG DUMP ====================');
    buf.writeln('App: ${info.appName} ${info.version}+${info.buildNumber}');
    buf.writeln('Package: ${info.packageName}');
    buf.writeln('OS: $os');
    buf.writeln('OS Version: $osVer');
    buf.writeln('');

    // ---------- Flags / Prefs ----------
    final prefs = await SharedPreferences.getInstance();
    final bankConnected = prefs.getBool('bank_connected') ?? false;
    final lastSyncAt = prefs.getString('last_sync_at'); // set this when you sync
    buf.writeln('⚙️  FLAGS');
    buf.writeln('- bank_connected: $bankConnected');
    buf.writeln('- last_sync_at: ${lastSyncAt ?? "null"}');
    buf.writeln('');

    // ---------- DB meta ----------
    final db = await AppDatabase.instance.database;
    final userVersion = (await db.rawQuery('PRAGMA user_version;')).first.values.first;
    final fkOn = (await db.rawQuery('PRAGMA foreign_keys;')).first.values.first;
    String? dbPath;
    try {
      final dblist = await db.rawQuery('PRAGMA database_list;');
      final main = dblist.firstWhere((r) => (r['name'] as String?) == 'main', orElse: () => {});
      dbPath = (main['file'] ?? '') as String?;
    } catch (_) {}
    int dbBytes = 0;
    try {
      final pageSize = (await db.rawQuery('PRAGMA page_size;')).first.values.first as int;
      final pageCount = (await db.rawQuery('PRAGMA page_count;')).first.values.first as int;
      dbBytes = pageSize * pageCount;
    } catch (_) {}

    buf.writeln('🗄️  DATABASE');
    buf.writeln('- sqlite user_version: $userVersion');
    buf.writeln('- foreign_keys: $fkOn');
    if (dbPath != null && dbPath!.isNotEmpty) {
      buf.writeln('- path: $dbPath');
      buf.writeln('- size: ${_fmtBytes(dbBytes)} ($dbBytes bytes)');
    }

    // table info helper
    Future<String> tableInfo(String t) async {
      final cols = await db.rawQuery('PRAGMA table_info($t);');
      final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t')) ?? 0;
      return '• $t (rows: $cnt)\n  columns: ${cols.map((c) => c['name']).toList()}';
    }

    try { buf.writeln(await tableInfo('transactions')); } catch (_) {}
    try { buf.writeln(await tableInfo('recurring_transactions')); } catch (_) {}
    try { buf.writeln(await tableInfo('budgets')); } catch (_) {}
    try { buf.writeln(await tableInfo('categories')); } catch (_) {}
    buf.writeln('');

    // ---------- Indexes / Triggers ----------
    Future<void> dumpIndexesFor(String table) async {
      try {
        final idx = await db.rawQuery('PRAGMA index_list($table);');
        if (idx.isNotEmpty) {
          buf.writeln('   $table indexes: ${idx.map((e) => e['name']).toList()}');
        }
      } catch (_) {}
    }

    buf.writeln('🧩 INDEXES & TRIGGERS');
    await dumpIndexesFor('transactions');
    await dumpIndexesFor('categories');
    try {
      final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name;",
      );
      buf.writeln('   triggers: ${triggers.map((e) => e['name']).toList()}');
    } catch (_) {}
    buf.writeln('');

    // ---------- Budgets ----------
    buf.writeln('💰 BUDGETS');
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await db.query('budgets', orderBy: 'id ASC');
    } catch (_) {}
    if (rows.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final r in rows) {
        buf.writeln('- [${r['id']}] ${r['category_id']} | weekly_limit: ${r['weekly_limit']} | start: ${r['period_start']}');
      }
    }
    buf.writeln('');

    // ---------- Categories ----------
    buf.writeln('🏷️  CATEGORIES');
    try {
      // Top categories & actual txn counts (join) — ordered by usage_count then name
      final cats = await db.rawQuery('''
        SELECT
          c.id, c.name, c.usage_count, c.first_seen_at, c.last_used_at,
          IFNULL(COUNT(t.id), 0) AS tx_count
        FROM categories c
        LEFT JOIN transactions t ON t.category_id = c.id
        GROUP BY c.id
        ORDER BY c.usage_count DESC, c.name ASC
        LIMIT 50;
      ''');

      if (cats.isEmpty) {
        buf.writeln('(none)');
      } else {
        for (final c in cats) {
          final id = c['id'];
          final name = c['name'];
          final uc = c['usage_count'];
          final txc = c['tx_count'];
          final last = c['last_used_at'] ?? '';
          final delta = (uc is int && txc is int) ? (uc - txc) : 0;
          final mismatch = delta == 0 ? '' : '  ⚠︎ usage≠actual (Δ=$delta)';
          buf.writeln('- [$id] $name | usage_count=$uc | tx=$txc | last_used=$last$mismatch');
        }
        if (cats.length >= 50) buf.writeln('  ...(only first 50 shown)');
      }

      // Mismatch summary
      final mismatches = await db.rawQuery('''
        SELECT COUNT(1) AS cnt
        FROM (
          SELECT c.id, c.usage_count, IFNULL(COUNT(t.id),0) AS txc
          FROM categories c
          LEFT JOIN transactions t ON t.category_id = c.id
          GROUP BY c.id
          HAVING c.usage_count != IFNULL(COUNT(t.id),0)
        )
      ''');
      final mm = (mismatches.first['cnt'] as num?)?.toInt() ?? 0;
      if (mm > 0) {
        buf.writeln('  → ⚠︎ categories with usage_count mismatch: $mm');
      }

      // Orphans / empties
      final orphanTxn = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM transactions t
        LEFT JOIN categories c ON c.id = t.category_id
        WHERE t.category_id IS NOT NULL AND c.id IS NULL
      ''')) ?? 0;
      final emptyCats = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM categories c
        LEFT JOIN transactions t ON t.category_id = c.id
        WHERE t.id IS NULL
      ''')) ?? 0;
      buf.writeln('  orphans: txns→missing category: $orphanTxn');
      buf.writeln('  empty categories (no txns): $emptyCats');
    } catch (e) {
      buf.writeln('(error reading categories: $e)');
    }
    buf.writeln('');

    // ---------- Recurring ----------
    final rec = await RecurringRepository.getAll();
    final weekly = rec.where((r) => r.frequency == 'weekly').toList();
    final monthly = rec.where((r) => r.frequency == 'monthly').toList();

    buf.writeln('🔁 RECURRING (weekly: ${weekly.length}, monthly: ${monthly.length})');
    if (rec.isEmpty) {
      buf.writeln('(none)');
    } else {
      if (weekly.isNotEmpty) {
        buf.writeln('— WEEKLY —');
        for (final r in weekly) {
          buf.writeln('  • ${r.description}  \$${r.amount.toStringAsFixed(2)}  next: ${r.nextDueDate}');
        }
      }
      if (monthly.isNotEmpty) {
        buf.writeln('— MONTHLY —');
        double monthlyTotal = 0;
        for (final r in monthly) {
          monthlyTotal += r.amount;
          final weeklyReserve = r.amount / 4.33;
          buf.writeln('  • ${r.description}  \$${r.amount.toStringAsFixed(2)} '
              '(reserve ≈ \$${weeklyReserve.toStringAsFixed(2)}/wk)  next: ${r.nextDueDate}');
        }
        buf.writeln('  total monthly = \$${monthlyTotal.toStringAsFixed(2)} '
            '→ reserve needed ≈ \$${(monthlyTotal / 4.33).toStringAsFixed(2)}/wk');
      }
    }
    buf.writeln('');

    // ---------- Transactions ----------
    final txns = await TransactionRepository.getAll();
    final firstDate = txns.isEmpty ? '-' : txns.last.date;
    final lastDate = txns.isEmpty ? '-' : txns.first.date;
    final totalIncome = (await db.rawQuery(
      "SELECT IFNULL(SUM(amount),0) AS v FROM transactions WHERE type='income';",
    )).first['v'] as num;
    final totalExpense = (await db.rawQuery(
      "SELECT IFNULL(SUM(amount),0) AS v FROM transactions WHERE type='expense';",
    )).first['v'] as num;
    final spentThisWeek = await TransactionRepository.getThisWeekExpenses();

    buf.writeln('🧾 TRANSACTIONS');
    buf.writeln('- count: ${txns.length}');
    buf.writeln('- date range: $firstDate → $lastDate');
    buf.writeln('- total income: \$${(totalIncome).toStringAsFixed(2)}');
    buf.writeln('- total expense: \$${(totalExpense).toStringAsFixed(2)} (raw sign)');
    buf.writeln('- spent this week: \$${spentThisWeek.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('First 50 rows (newest first):');
    for (final t in txns.take(50)) {
      buf.writeln('  • ${t.date} | ${t.type.padRight(7)} | \$${t.amount.toStringAsFixed(2)} | ${t.description}');
    }
    if (txns.length > 50) buf.writeln('  ...(only first 50 shown)');
    buf.writeln('');

    // ---------- Integrity / Consistency checks ----------
    buf.writeln('🔍 CONSISTENCY CHECKS');
    final warnings = <String>[];

    // 0) PRAGMA integrity_check
    try {
      final ic = await db.rawQuery('PRAGMA integrity_check;');
      final res = (ic.first.values.first ?? '').toString();
      if (res != 'ok') warnings.add('integrity_check: $res');
    } catch (_) {}

    // 1) Wrong sign vs type
    for (final t in txns.take(500)) { // limit to keep fast
      if (t.type == 'income' && t.amount < 0) {
        warnings.add('Income with negative amount: ${t.date} ${t.description} \$${t.amount}');
      }
      if (t.type == 'expense' && t.amount > 0) {
        warnings.add('Expense with positive amount: ${t.date} ${t.description} \$${t.amount}');
      }
    }

    // 2) Uncategorised
    final uncategorised = txns.where((t) => t.categoryId == null).length;
    if (uncategorised > 0) {
      warnings.add('Transactions without categoryId: $uncategorised');
    }

    // 3) Duplicate akahu_id (only if column exists)
    bool hasAkahuId = false;
    try {
      final cols = await db.rawQuery('PRAGMA table_info(transactions);');
      hasAkahuId = cols.any((c) => c['name'] == 'akahu_id');
    } catch (_) {}
    if (hasAkahuId) {
      final dups = await db.rawQuery('''
        SELECT akahu_id, COUNT(*) c 
        FROM transactions 
        WHERE akahu_id IS NOT NULL 
        GROUP BY akahu_id HAVING COUNT(*) > 1
      ''');
      if (dups.isNotEmpty) {
        warnings.add('Duplicate akahu_id rows: ${dups.length}');
      }
    }

    // 4) Budgets present?
    if (rows.isEmpty) {
      warnings.add('No budgets configured — weekly budget will be \$0.');
    }

    if (warnings.isEmpty) {
      buf.writeln('(no issues detected)');
    } else {
      for (final w in warnings) buf.writeln('- $w');
    }

    buf.writeln('======================================================');

    setState(() => _text = buf.toString());
  }

  /// Renders the scrollable text blob plus refresh action.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Data'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}
