/// ---------------------------------------------------------------------------
/// File: budget_suggestion_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   View-model for the Budget Build flow. Represents a single category
///   suggestion derived from historical spending and system signals (e.g.,
///   detected recurring transactions).
///
/// Notes:
///   - `weeklySuggested` is a normalized weekly spend estimate over the
///     chosen lookback window.
///   - `hasRecurring` elevates this suggestion's priority in UI ordering.
///   - `usageCount` comes from the categories table and indicates how often
///     the category is referenced by transactions (popularity / familiarity).
/// ---------------------------------------------------------------------------

class BudgetSuggestionModel {
  final int? categoryId;               // may be null for "Uncategorized"
  final String categoryName;           // display label
  final double weeklySuggested;        // normalized weekly spend
  final int usageCount;                // categories.usage_count
  final int txCount;                   // transactions in the window
  final bool hasRecurring;             // true if RecurringRepository has this category
  final bool isUncategorized;          // helpful for disabling selection
  final double priorityScore;          // derived for ordering (desc)

  const BudgetSuggestionModel({
    required this.categoryId,
    required this.categoryName,
    required this.weeklySuggested,
    required this.usageCount,
    required this.txCount,
    required this.hasRecurring,
    required this.isUncategorized,
    required this.priorityScore,
  });

  BudgetSuggestionModel copyWith({
    int? categoryId,
    String? categoryName,
    double? weeklySuggested,
    int? usageCount,
    int? txCount,
    bool? hasRecurring,
    bool? isUncategorized,
    double? priorityScore,
  }) {
    return BudgetSuggestionModel(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      weeklySuggested: weeklySuggested ?? this.weeklySuggested,
      usageCount: usageCount ?? this.usageCount,
      txCount: txCount ?? this.txCount,
      hasRecurring: hasRecurring ?? this.hasRecurring,
      isUncategorized: isUncategorized ?? this.isUncategorized,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }
}
