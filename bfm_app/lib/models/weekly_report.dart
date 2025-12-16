/// ---------------------------------------------------------------------------
/// File: lib/models/weekly_report.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Data structures that represent the auto-generated weekly insights report.
///
/// Called by:
///   `insights_service.dart`, `insights_screen.dart`, and
///   `weekly_report_repository.dart`.
///
/// Inputs / Outputs:
///   Serialise to/from JSON for storage, provide helper getters for UI labels.
/// ---------------------------------------------------------------------------
import 'dart:convert';

import 'package:bfm_app/models/goal_model.dart';

/// Summarises a single category's budget vs spend for a week.
class CategoryWeeklySummary {
  final String label;
  final double budget;
  final double spent;

  const CategoryWeeklySummary({
    required this.label,
    required this.budget,
    required this.spent,
  });

  /// Positive number when under budget, negative when overspent.
  double get variance => budget - spent;

  /// Hydrates from stored JSON.
  factory CategoryWeeklySummary.fromJson(Map<String, dynamic> json) {
    return CategoryWeeklySummary(
      label: json['label'] as String? ?? 'Category',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Serialises back to JSON for storage/export.
  Map<String, dynamic> toJson() => {
        'label': label,
        'budget': budget,
        'spent': spent,
      };
}

/// Describes how a particular goal performed in the given week.
class GoalWeeklyOutcome {
  final GoalModel goal;
  final bool credited;
  final double amountDelta;
  final String message;

  const GoalWeeklyOutcome({
    required this.goal,
    required this.credited,
    required this.amountDelta,
    required this.message,
  });

  /// Hydrates from JSON, including nested goal payload.
  factory GoalWeeklyOutcome.fromJson(Map<String, dynamic> json) {
    return GoalWeeklyOutcome(
      goal: GoalModel.fromMap((json['goal'] as Map?)?.cast<String, dynamic>() ?? const {}),
      credited: json['credited'] as bool? ?? false,
      amountDelta: (json['amountDelta'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
    );
  }

  /// Serialises back to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'goal': goal.toMap(includeId: true),
        'credited': credited,
        'amountDelta': amountDelta,
        'message': message,
      };
}

/// Complete weekly insights bundle constructed by `InsightsService`.
class WeeklyInsightsReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<CategoryWeeklySummary> categories;
  final List<CategoryWeeklySummary> topCategories;
  final double totalBudget;
  final double totalSpent;
  final double totalIncome;
  final bool metBudget;
  final List<GoalWeeklyOutcome> goalOutcomes;

  const WeeklyInsightsReport({
    required this.weekStart,
    required this.weekEnd,
    required this.categories,
    required this.topCategories,
    required this.totalBudget,
    required this.totalSpent,
    required this.totalIncome,
    required this.metBudget,
    required this.goalOutcomes,
  });

  /// Human readable label (YYYY-MM-DD → YYYY-MM-DD).
  String get weekLabel {
    final start = _fmtDay(weekStart);
    final end = _fmtDay(weekEnd);
    return "$start → $end";
  }

  /// Net savings for the week (income minus spend).
  double get savingsDelta => totalIncome - totalSpent;

  /// ISO strings for start/end (used everywhere else).
  String get weekStartIso => _fmtDay(weekStart);
  String get weekEndIso => _fmtDay(weekEnd);

  /// Serialises the full report to JSON.
  Map<String, dynamic> toJson() => {
        'weekStart': weekStartIso,
        'weekEnd': weekEndIso,
        'categories': categories.map((c) => c.toJson()).toList(),
        'topCategories': topCategories.map((c) => c.toJson()).toList(),
        'totalBudget': totalBudget,
        'totalSpent': totalSpent,
        'totalIncome': totalIncome,
        'metBudget': metBudget,
        'goalOutcomes': goalOutcomes.map((g) => g.toJson()).toList(),
      };

  /// Hydrates a report from JSON, parsing nested category/goal lists safely.
  factory WeeklyInsightsReport.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? value) =>
        value == null || value.isEmpty ? DateTime.now() : DateTime.parse(value);
    final catList = (json['categories'] as List?)
            ?.map((e) => CategoryWeeklySummary.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList() ??
        const <CategoryWeeklySummary>[];
    final topCatList = (json['topCategories'] as List?)
            ?.map((e) => CategoryWeeklySummary.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList() ??
        const <CategoryWeeklySummary>[];
    final goalList = (json['goalOutcomes'] as List?)
            ?.map((e) =>
                GoalWeeklyOutcome.fromJson((e as Map).cast<String, dynamic>()))
            .toList() ??
        const <GoalWeeklyOutcome>[];
    return WeeklyInsightsReport(
      weekStart: parseDate(json['weekStart'] as String?),
      weekEnd: parseDate(json['weekEnd'] as String?),
      categories: catList,
      topCategories: topCatList,
      totalBudget: (json['totalBudget'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0.0,
      metBudget: json['metBudget'] as bool? ?? false,
      goalOutcomes: goalList,
    );
  }

  /// Convenience helper to encode to a JSON string for database storage.
  String toEncodedJson() => jsonEncode(toJson());

  /// Opposite of [toEncodedJson]; decodes and parses a stored string.
  static WeeklyInsightsReport fromEncodedJson(String encoded) =>
      WeeklyInsightsReport.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);

  /// Formats a DateTime as YYYY-MM-DD for consistent serialization.
  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}

/// Table row tying an auto-increment id to a serialized report blob.
class WeeklyReportEntry {
  final int? id;
  final WeeklyInsightsReport report;

  const WeeklyReportEntry({this.id, required this.report});

  /// Expose week start so repository callers can index quickly.
  DateTime get weekStart => report.weekStart;

  /// Hydrates an entry from SQLite (`data` column holds JSON string).
  factory WeeklyReportEntry.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as String? ?? '{}';
    return WeeklyReportEntry(
      id: map['id'] as int?,
      report: WeeklyInsightsReport.fromEncodedJson(data),
    );
  }
}

