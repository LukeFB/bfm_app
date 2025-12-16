/// ---------------------------------------------------------------------------
/// File: lib/models/budget_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Strongly typed representation of a weekly budget allowance row.
///
/// Called by:
///   `budget_repository.dart` for persistence and `budget_build_screen.dart`
///   for rendering/editing budgets in the UI.
///
/// Inputs / Outputs:
///   Provides constructors that convert to/from SQLite maps, plus helpers to
///   identify goal-linked budgets.
/// ---------------------------------------------------------------------------

/// Immutable weekly budget record with optional goal linkage.
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

  /// Rebuilds a model from a SQLite row, casting numbers to doubles as needed.
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

  /// Serialises the model back to a map.
  /// Includes the id only when `includeId` is true so inserts stay auto-inc.
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

  /// Quick flag for budgets tied to a goal (used to style list items).
  bool get isGoalBudget => goalId != null;
}
