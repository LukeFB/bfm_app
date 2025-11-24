import 'dart:convert';

import 'package:bfm_app/models/goal_model.dart';

class CategoryWeeklySummary {
  final String label;
  final double budget;
  final double spent;

  const CategoryWeeklySummary({
    required this.label,
    required this.budget,
    required this.spent,
  });

  double get variance => budget - spent;

  factory CategoryWeeklySummary.fromJson(Map<String, dynamic> json) {
    return CategoryWeeklySummary(
      label: json['label'] as String? ?? 'Category',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'budget': budget,
        'spent': spent,
      };
}

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

  factory GoalWeeklyOutcome.fromJson(Map<String, dynamic> json) {
    return GoalWeeklyOutcome(
      goal: GoalModel.fromMap((json['goal'] as Map?)?.cast<String, dynamic>() ?? const {}),
      credited: json['credited'] as bool? ?? false,
      amountDelta: (json['amountDelta'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'goal': goal.toMap(includeId: true),
        'credited': credited,
        'amountDelta': amountDelta,
        'message': message,
      };
}

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

  String get weekLabel {
    final start = _fmtDay(weekStart);
    final end = _fmtDay(weekEnd);
    return "$start → $end";
  }

  double get savingsDelta => totalIncome - totalSpent;

  String get weekStartIso => _fmtDay(weekStart);
  String get weekEndIso => _fmtDay(weekEnd);

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

  String toEncodedJson() => jsonEncode(toJson());

  static WeeklyInsightsReport fromEncodedJson(String encoded) =>
      WeeklyInsightsReport.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);

  static String _fmtDay(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}

class WeeklyReportEntry {
  final int? id;
  final WeeklyInsightsReport report;

  const WeeklyReportEntry({this.id, required this.report});

  DateTime get weekStart => report.weekStart;

  factory WeeklyReportEntry.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as String? ?? '{}';
    return WeeklyReportEntry(
      id: map['id'] as int?,
      report: WeeklyInsightsReport.fromEncodedJson(data),
    );
  }
}

