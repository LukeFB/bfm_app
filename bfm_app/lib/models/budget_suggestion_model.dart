/// ---------------------------------------------------------------------------
/// File: lib/models/budget_suggestion_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `budget_analysis_service.dart` and the Budget Build UI when surfacing
///     suggested categories/description groups to include in a plan.
///
/// Purpose:
///   - Wraps analytics output into a friendlier view-model so the UI can render
///     rows without understanding the raw SQL shape.
///
/// Inputs:
///   - Derived metrics such as weeklySuggested, tx counts, recurring flags.
///
/// Outputs:
///   - Structured data the UI can map to list tiles, plus helpers for
///     understanding if the item is uncategorized.
/// ---------------------------------------------------------------------------

/// View-model representing a recommended budget entry or uncategorized cluster.
class BudgetSuggestionModel {
  final int? categoryId;
  final String categoryName;
  final double weeklySuggested;
  final int usageCount;
  final int txCount;
  final bool hasRecurring;

  // Uncategorized sort by description
  final bool isUncategorizedGroup;
  final String? description;

  const BudgetSuggestionModel({
    required this.categoryId,
    required this.categoryName,
    required this.weeklySuggested,
    required this.usageCount,
    required this.txCount,
    required this.hasRecurring,
    this.isUncategorizedGroup = false,
    this.description,
  });

  /// `true` when the item has no categoryId and is not a grouped description row
  /// (meaning it's a direct "uncategorized" bucket).
  bool get isUncategorized => categoryId == null && !isUncategorizedGroup;
}
