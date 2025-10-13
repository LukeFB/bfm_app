/// ---------------------------------------------------------------------------
/// File: lib/models/budget_suggestion_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Lightweight view-model used by the Budget Build screen. Represents either
///   (a) a normal category suggestion, or (b) an "uncategorized-by-description"
///   suggestion that the user can categorize inline.
///
/// Fields:
///   - categoryId         (null for uncategorized-by-description rows)
///   - categoryName       (for uncategorized rows this is the description label)
///   - weeklySuggested
///   - usageCount
///   - txCount
///   - hasRecurring
///   - isUncategorizedGroup
///   - description        (only for uncategorized groups)
/// ---------------------------------------------------------------------------

class BudgetSuggestionModel {
  final int? categoryId;
  final String categoryName;
  final double weeklySuggested;
  final int usageCount;
  final int txCount;
  final bool hasRecurring;

  // "Uncategorized by description"
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

  bool get isUncategorized => categoryId == null && !isUncategorizedGroup;
}
