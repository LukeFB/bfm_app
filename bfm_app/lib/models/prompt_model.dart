// -----------------------------------------------------------------------------
// Author: Jack Unsworth
// -----------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class PromptModel {
  final Database _db;

  PromptModel(this._db);

  /// Builds the full private context string for the AI assistant.
  /// includeBudgets → embed a brief budget summary
  /// includeReferrals → embed local referral list

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
    final budgets = await _db.query(
      'budgets',
      orderBy: 'created_at DESC',
    );

    if (budgets.isEmpty) {
      return "No active budgets stored locally.\n";
    }

    final buffer = StringBuffer();
    buffer.writeln("Current weekly budgets:\n");

    for (final b in budgets) {
      final id = b['id'];
      final categoryId = b['category_id'];
      final weeklyLimit = b['weekly_limit'];
      final start = b['period_start']?.toString() ?? 'Unknown start';
      final end = b['period_end']?.toString() ?? 'Ongoing';

      final weeklyLimitVal = (weeklyLimit is num) ? weeklyLimit : 0.0;
      final category = await _getCategoryName(categoryId);

      buffer.writeln(
          "- ${category ?? 'Uncategorised'}: limit \$${weeklyLimitVal.toStringAsFixed(2)} (from $start to $end)");
    }

    buffer.writeln();
    return buffer.toString();
  }

  Future<String?> _getCategoryName(dynamic categoryId) async {
    if (categoryId == null) return null;
    final results = await _db.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [categoryId],
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
    final referrals = await _db.query(
      'referrals',
      orderBy: 'created_at DESC',
    );

    if (referrals.isEmpty) {
      return "No referral resources stored locally.\n";
    }

    final buffer = StringBuffer();
    buffer.writeln("Available referral resources:\n");

    for (final r in referrals) {
      final title = r['title'] is String ? r['title'] as String : 'Untitled';
      final desc = r['description'] is String ? r['description'] as String : '';
      final link = r['link'] is String ? r['link'] as String : '';
      final category = r['category'] is String ? r['category'] as String : '';
      final source = r['source'] is String ? r['source'] as String : 'BFM';

      buffer.writeln(
        "- $title (${category.isNotEmpty ? category : 'General'}) — $desc "
            "${link.isNotEmpty ? '[$link]' : ''} (Source: $source)",
      );
    }

    buffer.writeln();
    return buffer.toString();
  }
}
