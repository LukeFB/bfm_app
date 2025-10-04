import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _text = 'Loading…';

  @override
  void initState() {
    super.initState();
    _load();
  }

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
    buf.writeln('🗄️  DATABASE');
    buf.writeln('- sqlite user_version: $userVersion');

    // table info helper
    Future<String> tableInfo(String t) async {
      final cols = await db.rawQuery('PRAGMA table_info($t);');
      final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t')) ?? 0;
      return '• $t (rows: $cnt)\n  columns: ${cols.map((c) => c['name']).toList()}';
    }

    buf.writeln(await tableInfo('transactions'));
    buf.writeln(await tableInfo('recurring_transactions'));
    // If you have budgets & categories tables:
    try { buf.writeln(await tableInfo('budgets')); } catch (_) {}
    try { buf.writeln(await tableInfo('categories')); } catch (_) {}
    buf.writeln('');

    // ---------- Budgets ----------
    buf.writeln('💰 BUDGETS');
    // read budgets raw to avoid repo coupling
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await db.query('budgets', orderBy: 'id ASC');
    } catch (_) {}
    if (rows.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final r in rows) {
        buf.writeln('- [${r['id']}] ${r['name'] ?? "Unnamed"} | weekly_limit: ${r['weekly_limit']}');
      }
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

    // ---------- Consistency checks ----------
    buf.writeln('🔍 CONSISTENCY CHECKS');
    final warnings = <String>[];

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

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _export() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/bfm_debug_${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt';
    final f = File(path);
    await f.writeAsString(_text);
    await Share.shareXFiles([XFile(path)], text: 'BFM Debug Dump');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Data'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          IconButton(onPressed: _copy, icon: const Icon(Icons.copy), tooltip: 'Copy'),
          IconButton(onPressed: _export, icon: const Icon(Icons.ios_share), tooltip: 'Export'),
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
