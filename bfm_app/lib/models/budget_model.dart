/// ---------------------------------------------------------------------------
/// File: budget_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents a weekly budget allowance for a single category.
///
/// DB mapping:
///   id, category_id, weekly_limit, period_start, period_end, created_at, updated_at
///
/// Guidance:
///   - `period_start` is stored as YYYY-MM-DD representing the week start.
///   - Aggregation over budgets (e.g. total weekly budget) should be performed
///     in a service/repository layer to allow caching and unit tests.
/// ---------------------------------------------------------------------------

class BudgetModel {
  final int? id;
  final int categoryId;
  final double weeklyLimit;
  final String periodStart; // YYYY-MM-DD (week start)
  final String? periodEnd; // optional
  final String? createdAt;
  final String? updatedAt;

  const BudgetModel({
    this.id,
    required this.categoryId,
    required this.weeklyLimit,
    required this.periodStart,
    this.periodEnd,
    this.createdAt,
    this.updatedAt,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> m) {
    return BudgetModel(
      id: m['id'] as int?,
      categoryId: m['category_id'] as int,
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
      'weekly_limit': weeklyLimit,
      'period_start': periodStart,
      'period_end': periodEnd,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }
}
