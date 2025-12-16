/// ---------------------------------------------------------------------------
/// File: lib/models/prompt_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `ai_client.dart` and `context_builder.dart` when building the system
///     prompt for the assistant.
///
/// Purpose:
///   - Pulls data from SQLite, summarises it, and emits a human-readable
///     context block the AI can consume before answering a user.
///
/// Inputs:
///   - Direct sqflite `Database` handle plus boolean flags for each section.
///
/// Outputs:
///   - A multi-section string describing budgets, categories, goals, referrals,
///     events, reports, and alerts.
///
/// Notes:
///   - Keep sections concise; this text feeds directly into LLM prompts where
///     every token matters.
/// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Builds AI prompt context by querying the local database.
class PromptModel {
  final Database _db;

  PromptModel(this._db);

  /// Builds the full private context string for the AI assistant.
  /// Embed summaries for budgets, goals, referrals, reports, and events.
  Future<String> buildPrompt({
    bool includeBudgets = true,
    bool includeCategories = true,
    bool includeReferrals = true,
    bool includeGoals = true,
    bool includeReports = true,
    bool includeEvents = true,
    bool includeAlerts = true,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("### USER CONTEXT ###\n");

    if (includeBudgets) {
      buffer.writeln(await _buildBudgetContext());
    }

    if (includeCategories) {
      buffer.writeln(await _buildCategorySpendContext());
    }

    if (includeGoals) {
      buffer.writeln(await _buildGoalContext());
    }

    if (includeReferrals) {
      buffer.writeln(await _buildReferralContext());
    }

    if (includeEvents) {
      buffer.writeln(await _buildEventsContext());
    }

    if (includeReports) {
      buffer.writeln(await _buildWeeklyReportContext());
    }

    if (includeAlerts) {
      buffer.writeln(await _buildAlertContext());
    }

    buffer.writeln("End of context.\n");
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  //  Budget context
  // ---------------------------------------------------------------------------

  /// Formats a DateTime into `YYYY-MM-DD` so prompt sections stay consistent.
  String _fmtIsoDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Summarises the latest budgets (capped for token control) so the model knows
  /// current weekly limits per category.
  Future<String> _buildBudgetContext() async {
    // explicit columns + limit for token control and resilience to schema drift.
    const int _kMaxBudgets = 12; // cap items to avoid large prompts.
    final budgets = await _db.query(
      'budgets',
      columns: [
        'id',
        'category_id',
        'weekly_limit',
        'period_start',
        'period_end',
        'created_at',
      ],
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

  /// Summarises this week's category spend vs recent budgets so the model can
  /// cite where money is going right now.
  Future<String> _buildCategorySpendContext() async {
    // Limit rows to keep the prompt concise while still giving coverage.
    const int _kMaxCategories = 12;

    final today = DateTime.now();
    final monday =
        DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    final start = _fmtIsoDay(monday);
    final end = _fmtIsoDay(today);

    final categoryRows = await _db.query(
      'categories',
      columns: ['id', 'name', 'usage_count'],
      orderBy: 'usage_count DESC, name ASC',
      limit: 50,
    );
    final categoryNames = <int, String>{};
    for (final row in categoryRows) {
      final id = row['id'] as int?;
      final name = (row['name'] ?? 'Category').toString().trim();
      if (id != null) {
        categoryNames[id] = name.isEmpty ? 'Category' : name;
      }
    }

    final budgetByCategory = await _latestBudgetsByCategory();

    final spendRows = await _db.rawQuery(
      '''
      SELECT category_id, ABS(SUM(amount)) AS spent
      FROM transactions
      WHERE type = 'expense'
        AND date BETWEEN ? AND ?
      GROUP BY category_id
      ORDER BY spent DESC;
      ''',
      [start, end],
    );

    final entries = <Map<String, dynamic>>[];
    for (final row in spendRows) {
      final dynamic catRaw = row['category_id'];
      final int? catId =
          (catRaw is int) ? catRaw : int.tryParse(catRaw?.toString() ?? '');
      final spent = (row['spent'] as num?)?.toDouble() ?? 0.0;
      final label = catId == null
          ? 'Uncategorized'
          : (categoryNames[catId] ?? 'Category');
      final budget = catId != null ? budgetByCategory[catId] : null;
      entries.add({
        'label': label,
        'spent': spent,
        'budget': budget,
        'categoryId': catId,
      });
    }

    // Add any budgeted categories with zero spend so the assistant knows
    // they exist this week.
    for (final entry in budgetByCategory.entries) {
      final catId = entry.key;
      final alreadyIncluded =
          entries.any((e) => e['categoryId'] == catId);
      if (!alreadyIncluded) {
        final label = categoryNames[catId] ?? 'Category';
        entries.add({
          'label': label,
          'spent': 0.0,
          'budget': entry.value,
          'categoryId': catId,
        });
      }
    }

    if (entries.isEmpty) {
      if (categoryNames.isEmpty) {
        return "No categories or weekly spending recorded yet.\n";
      }
      final preview = categoryNames.values.take(8).join(', ');
      return "Categories tracked: $preview\n";
    }

    // Sort descending by spend, then alphabetically to keep deterministic.
    entries.sort((a, b) {
      final spentA = (a['spent'] as double?) ?? 0.0;
      final spentB = (b['spent'] as double?) ?? 0.0;
      final cmp = spentB.compareTo(spentA);
      if (cmp != 0) return cmp;
      return (a['label'] as String).toLowerCase().compareTo(
            (b['label'] as String).toLowerCase(),
          );
    });

    final buffer = StringBuffer(
      "Categories and weekly spend (Mon->today):\n",
    );
    final trimmed = entries.take(_kMaxCategories);
    for (final entry in trimmed) {
      final spent = (entry['spent'] as num?)?.toDouble() ?? 0.0;
      final budget = entry['budget'] as double?;
      final label = entry['label'] as String;
      buffer.writeln(
        "- $label: \$${spent.toStringAsFixed(spent >= 100 ? 0 : 2)}"
        "${budget != null ? ' vs budget \$${budget.toStringAsFixed(0)}' : ''}",
      );
    }
    if (entries.length > _kMaxCategories) {
      buffer.writeln("- ... ${entries.length - _kMaxCategories} more categories tracked");
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Looks up the most recent budget period and returns totals per category id.
  Future<Map<int, double>> _latestBudgetsByCategory() async {
    final latest = await _db.rawQuery(
      'SELECT MAX(period_start) AS period FROM budgets',
    );
    final period = latest.isNotEmpty ? latest.first['period']?.toString() : null;
    if (period == null || period.isEmpty) return {};

    final rows = await _db.rawQuery(
      '''
      SELECT category_id, SUM(weekly_limit) AS total_limit
      FROM budgets
      WHERE period_start = ?
      GROUP BY category_id;
      ''',
      [period],
    );

    final map = <int, double>{};
    for (final row in rows) {
      final dynamic catRaw = row['category_id'];
      final int? catId =
          (catRaw is int) ? catRaw : int.tryParse(catRaw?.toString() ?? '');
      if (catId == null) continue;
      final limit = (row['total_limit'] as num?)?.toDouble() ?? 0.0;
      map[catId] = limit;
    }
    return map;
  }

  /// Safely resolves a category name from the DB regardless of int/string id
  /// formats. Returns null when not found.
  Future<String?> _getCategoryName(dynamic categoryId) async {
    if (categoryId == null) return null;

    // normalize to integer for reliable lookups.
    final int? id = (categoryId is int)
        ? categoryId
        : int.tryParse(categoryId.toString());
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

  /// Generates a savings goal summary with progress %, weekly plan, and
  /// remaining amount so the assistant can coach around goals.
  Future<String> _buildGoalContext() async {
    const int _kMaxGoals = 6;
    final goals = await _db.query(
      'goals',
      columns: ['name', 'amount', 'saved_amount', 'weekly_contribution'],
      orderBy: 'amount DESC',
      limit: _kMaxGoals,
    );

    if (goals.isEmpty) {
      return "No savings goals stored locally.\n";
    }

    final buffer = StringBuffer("Savings goals progress:\n");
    for (final g in goals) {
      final name = (g['name'] ?? 'Goal').toString();
      final target = (g['amount'] as num?)?.toDouble() ?? 0.0;
      final saved = (g['saved_amount'] as num?)?.toDouble() ?? 0.0;
      final weekly = (g['weekly_contribution'] as num?)?.toDouble() ?? 0.0;
      final pct = target == 0
          ? 0
          : (saved / target * 100).clamp(0, 999).toDouble();
      final remaining = (target - saved).clamp(0, 999999);
      buffer.writeln(
        "- $name: \$${saved.toStringAsFixed(0)} saved "
        "of \$${target.toStringAsFixed(0)} "
        "(~${pct.toStringAsFixed(0)}%, weekly plan \$${weekly.toStringAsFixed(0)}, "
        "\$${remaining.toStringAsFixed(0)} remaining)",
      );
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Lists the most recent active referral resources, including contact details,
  /// so the assistant can suggest real providers.
  Future<String> _buildReferralContext() async {
    final referrals = await _db.query(
      'referrals',
      columns: [
        'organisation_name',
        'services',
        'phone',
        'email',
        'website',
        'region',
        'demographics',
        'availability',
        'is_active',
      ],
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
    );

    if (referrals.isEmpty) {
      return "No referral resources stored locally.\n";
    }

    final buffer = StringBuffer("Available referral resources:\n");
    for (final r in referrals) {
      final name = (r['organisation_name'] ?? 'Community service')
          .toString()
          .trim();
      final services = (r['services'] ?? '').toString().trim();
      final region = (r['region'] ?? '').toString().trim();
      final audience = (r['demographics'] ?? '').toString().trim();
      final availability = (r['availability'] ?? '').toString().trim();

      final contactParts = <String>[];
      if ((r['phone'] ?? '').toString().trim().isNotEmpty) {
        contactParts.add('phone ${r['phone']}');
      }
      if ((r['email'] ?? '').toString().trim().isNotEmpty) {
        contactParts.add(r['email'].toString().trim());
      }
      if ((r['website'] ?? '').toString().trim().isNotEmpty) {
        contactParts.add(r['website'].toString().trim());
      }
      final contactLine = contactParts.isEmpty
          ? ''
          : ' Contact: ${contactParts.join(', ')}';

      final descriptors = <String>[];
      if (services.isNotEmpty) descriptors.add(services);
      if (availability.isNotEmpty) descriptors.add('Hours: $availability');
      if (audience.isNotEmpty) descriptors.add('For: $audience');
      if (region.isNotEmpty) descriptors.add('Region: $region');

      buffer.writeln(
        "- $name${descriptors.isEmpty ? '' : ' — ${descriptors.join(' | ')}'}$contactLine",
      );
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Summarises upcoming events (end date filter) for quick suggestions.
  Future<String> _buildEventsContext() async {
    final nowIso = DateTime.now().toIso8601String();
    final events = await _db.query(
      'events',
      columns: ['title', 'end_date'],
      where: 'end_date IS NOT NULL AND end_date >= ?',
      whereArgs: [nowIso],
      orderBy: 'end_date ASC',
      limit: 5,
    );

    if (events.isEmpty) {
      return "No upcoming campus events recorded.\n";
    }

    String fmt(dynamic value) {
      if (value == null) return '';
      final date = DateTime.tryParse(value.toString());
      if (date == null) return value.toString();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }

    final buffer = StringBuffer("Upcoming events:\n");
    for (final e in events) {
      final title = (e['title'] ?? 'Event').toString();
      final end = fmt(e['end_date']);
      buffer.writeln("- $title${end.isNotEmpty ? ' (ends $end)' : ''}");
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Pulls the latest weekly insight report JSON, extracts highlights, and
  /// outputs a compact paragraph the model can quote.
  Future<String> _buildWeeklyReportContext() async {
    final reports = await _db.query(
      'weekly_reports',
      columns: ['week_start', 'week_end', 'data'],
      orderBy: 'week_start DESC',
      limit: 1,
    );

    if (reports.isEmpty) {
      return "No weekly insights reports available yet.\n";
    }

    final row = reports.first;
    final weekStart = row['week_start']?.toString() ?? '';
    final weekEnd = row['week_end']?.toString() ?? '';
    Map<String, dynamic> parsed = const {};
    final rawData = row['data']?.toString();
    if (rawData != null && rawData.isNotEmpty) {
      try {
        parsed = jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {
        parsed = const {};
      }
    }

    final totalBudget = (parsed['totalBudget'] as num?)?.toDouble();
    final totalSpent = (parsed['totalSpent'] as num?)?.toDouble();
    final metBudget = parsed['metBudget'] as bool? ?? false;
    List<Map<String, dynamic>> parseCatList(dynamic raw) {
      return (raw as List?)
              ?.map((item) => (item is Map)
                  ? item.cast<String, dynamic>()
                  : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList() ??
          const <Map<String, dynamic>>[];
    }

    final categories = parseCatList(parsed['categories']);
    final topCategories = parseCatList(parsed['topCategories']);

    String catSpendSummary() {
      final list = categories.isNotEmpty ? categories : topCategories;
      if (list.isEmpty) return '';

      const cap = 8; // keep prompt lean while including more than top 3
      final buffer = StringBuffer("Category spend vs budget:\n");
      final trimmed = list.take(cap);
      for (final item in trimmed) {
        final label = (item['label'] ?? 'Category').toString();
        final spent = (item['spent'] as num?)?.toDouble() ?? 0.0;
        final budget = (item['budget'] as num?)?.toDouble() ?? 0.0;
        final variance = budget - spent;
        final varianceText = variance == 0
            ? 'on budget'
            : variance > 0
                ? 'under by \$${variance.abs().toStringAsFixed(0)}'
                : 'over by \$${variance.abs().toStringAsFixed(0)}';
        final budgetText = budget > 0
            ? "budget \$${budget.toStringAsFixed(0)}"
            : "no set budget";
        buffer.writeln(
          "- $label: spent \$${spent.toStringAsFixed(0)} vs $budgetText ($varianceText)",
        );
      }
      if (list.length > cap) {
        buffer.writeln("- ... ${list.length - cap} more categories");
      }
      return buffer.toString();
    }

    final buffer = StringBuffer(
      "Most recent weekly report ($weekStart → $weekEnd):\n",
    );
    if (totalBudget != null && totalSpent != null) {
      buffer.writeln(
        "- Budgeted \$${totalBudget.toStringAsFixed(0)}, spent \$${totalSpent.toStringAsFixed(0)}"
        " (${metBudget ? 'on track' : 'over plan'}).",
      );
    }
    final catDetails = catSpendSummary();
    if (catDetails.isNotEmpty) buffer.writeln(catDetails);
    buffer.writeln();
    return buffer.toString();
  }

  /// Lists a few of the latest alerts so the assistant can reinforce them in
  /// chat responses.
  Future<String> _buildAlertContext() async {
    final alerts = await _db.query(
      'alerts',
      columns: ['text', 'icon'],
      orderBy: 'id DESC',
      limit: 4,
    );
    if (alerts.isEmpty) {
      return "";
    }
    final buffer = StringBuffer("Active alerts:\n");
    for (final alert in alerts) {
      final icon = (alert['icon'] ?? '⚠️').toString();
      final text = (alert['text'] ?? '').toString();
      buffer.writeln("- $icon $text");
    }
    buffer.writeln();
    return buffer.toString();
  }
}
