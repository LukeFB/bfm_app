/// ---------------------------------------------------------------------------
/// File: budget_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents a weekly budget allowance for a single category.
///
/// DB mapping:
///   id, category_id, weekly_limit, period_start, period_end, created_at, updated_at
/// ---------------------------------------------------------------------------

class BudgetModel {
  final int? id;
  final int? categoryId;
  final int? goalId;
  final String? label;
  final double weeklyLimit;
  final String periodStart; // YYYY-MM-DD (week start)
  final String? periodEnd; // optional
  final String? createdAt;
  final String? updatedAt;

  const BudgetModel({
    this.id,
    this.categoryId,
    this.goalId,
    this.label,
    required this.weeklyLimit,
    required this.periodStart,
    this.periodEnd,
    this.createdAt,
    this.updatedAt,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> m) {
    return BudgetModel(
      id: m['id'] as int?,
      categoryId: m['category_id'] as int?,
      goalId: m['goal_id'] as int?,
      label: m['label'] as String?,
      weeklyLimit: (m['weekly_limit'] as num).toDouble(),
      periodStart: (m['period_start'] as String),
      periodEnd: m['period_end'] as String?,
      createdAt: m['created_at'] as String?,
      updatedAt: m['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'category_id': categoryId,
      'goal_id': goalId,
      'label': label,
      'weekly_limit': weeklyLimit,
      'period_start': periodStart,
      'period_end': periodEnd,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  bool get isGoalBudget => goalId != null;
}
