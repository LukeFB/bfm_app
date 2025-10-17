// -----------------------------------------------------------------------------
// File: prompt_model.dart
// Author: Jack Unsworth, Luke Fraser-Brown
// -----------------------------------------------------------------------------


import 'package:sqflite/sqflite.dart';

class PromptModel {
  final Database _db;

  PromptModel(this._db);

  /// Builds the full private context string for the AI assistant.
  /// Embed a brief budget summary
  /// TODO: Embed referral list
  Future<String> buildPrompt({
    bool includeBudgets = true,
    bool includeReferrals = true,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("### USER CONTEXT ###\n");

    if (includeBudgets) {
      buffer.writeln(await _buildBudgetContext());
    }

    if (includeReferrals) {
      buffer.writeln(await _buildReferralContext());
    }

    buffer.writeln("End of context.\n");
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  //  Budget context
  // ---------------------------------------------------------------------------

  Future<String> _buildBudgetContext() async {
    // explicit columns + limit for token control and resilience to schema drift.
    const int _kMaxBudgets = 12; // cap items to avoid large prompts.
    final budgets = await _db.query(
      'budgets',
      columns: ['id', 'category_id', 'weekly_limit', 'period_start', 'period_end', 'created_at'],
      orderBy: 'created_at DESC',
      limit: _kMaxBudgets,
    );

    if (budgets.isEmpty) {
      return "No active budgets stored locally.\n";
    }

    final buffer = StringBuffer();
    buffer.writeln("Current weekly budgets:\n");

    // simple date formatter to keep outputs compact and consistent.
    String _fmtDate(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      // Prints ISO yyyy-MM-dd when possible; otherwise returns as-is.
      return s.length >= 10 ? s.substring(0, 10) : s;
    }

    for (final b in budgets) {
      final categoryIdRaw = b['category_id'];
      final weeklyLimit = b['weekly_limit'];

      // category_id parsing to handle int/string variants.
      final int? categoryId = (categoryIdRaw is int)
          ? categoryIdRaw
          : int.tryParse(categoryIdRaw?.toString() ?? '');

      final start = _fmtDate(b['period_start']);
      final end = _fmtDate(b['period_end']);

      final weeklyLimitVal = (weeklyLimit is num) ? weeklyLimit : 0.0;
      final category = await _getCategoryName(categoryId);

      buffer.writeln(
        "- ${category ?? 'Uncategorised'}: limit \$${weeklyLimitVal.toStringAsFixed(2)}"
        "${start.isNotEmpty ? ' (from $start' : ''}"
        "${end.isNotEmpty ? (start.isNotEmpty ? ' to $end)' : ' to $end') : (start.isNotEmpty ? ')' : '')}",
      );
    }

    buffer.writeln();
    return buffer.toString();
  }

  Future<String?> _getCategoryName(dynamic categoryId) async {
    if (categoryId == null) return null;

    // normalize to integer for reliable lookups.
    final int? id = (categoryId is int) ? categoryId : int.tryParse(categoryId.toString());
    if (id == null) return null;

    final results = await _db.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      final name = results.first['name'];
      return (name is String) ? name : null;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  //  Referral context
  // ---------------------------------------------------------------------------

  Future<String> _buildReferralContext() async {

    return "No referral resources yet\n"; // TODO recieve referral list from backend

    // explicit columns + limit to protect tokens and tolerate schema changes.
  //  final referrals = await _db.query(
  //    'referrals',
  //    columns: ['title', 'description', 'link', 'category', 'source', 'created_at'],
  //    orderBy: 'created_at DESC',
  //    limit: _kMaxReferrals,
  //  );

  //  if (referrals.isEmpty) {
  //    return "No referral resources stored locally.\n";
  //  }

  //  final buffer = StringBuffer();
  //  buffer.writeln("Available referral resources:\n");
//
  //  for (final r in referrals) {
  //    final title = r['title'] is String ? r['title'] as String : 'Untitled';
  //    final desc = r['description'] is String ? r['description'] as String : '';
  //    final link = r['link'] is String ? r['link'] as String : '';
  //    final category = r['category'] is String ? r['category'] as String : '';
  //    final source = r['source'] is String ? r['source'] as String : 'BFM';
//
    //  final cat = category.isNotEmpty ? category : 'General';
  //    final linkPart = link.isNotEmpty ? ' [$link]' : '';
//
  //    buffer.writeln("- $title ($cat) — $desc$linkPart (Source: $source)");
  //  }
//
  //  buffer.writeln();
  //  return buffer.toString();
  }
}
