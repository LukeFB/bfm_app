/// ---------------------------------------------------------------------------
/// File: lib/models/recurring_transaction_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Encapsulates recurring payments/bills detected from transaction history.
///
/// Called by:
///   `recurring_repository.dart` for persistence and `budget_analysis_service.dart`
///   when generating alerts or weekly reminders.
///
/// Inputs / Outputs:
///   Offers helpers to convert to/from SQLite rows and determine when the next
///   payment is due.
/// ---------------------------------------------------------------------------

/// Immutable recurring transaction definition.
class RecurringTransactionModel {
  final int? id;
  final int categoryId;
  final double amount;
  final String frequency; // weekly
  final String nextDueDate; // YYYY-MM-DD
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  /// Captures all metadata needed to surface upcoming payments.
  const RecurringTransactionModel({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Hydrates from a SQLite map. Casts numeric columns to doubles where needed.
  factory RecurringTransactionModel.fromMap(Map<String, dynamic> m) {
    return RecurringTransactionModel(
      id: m['id'] as int?,
      categoryId: m['category_id'] as int,
      amount: (m['amount'] as num).toDouble(),
      frequency: m['frequency'] as String,
      nextDueDate: m['next_due_date'] as String,
      description: m['description'] as String?,
      createdAt: m['created_at'] as String?,
      updatedAt: m['updated_at'] as String?,
    );
  }

  /// Serialises back to a map for inserts/updates. Optionally includes id.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency,
      'next_due_date': nextDueDate,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  /// Calculates how many days remain until the next due date relative to `now`
  /// (defaults to today). Returns a large sentinel on parse failure.
  int daysUntilDue([DateTime? now]) {
    final n = now ?? DateTime.now();
    try {
      final due = DateTime.parse(nextDueDate);
      return due.difference(DateTime(n.year, n.month, n.day)).inDays;
    } catch (_) {
      return 999999; // treat unknown as far in future
    }
  }

  /// Convenience predicate that wraps `daysUntilDue` so alert code stays tidy.
  bool isDueWithin(int days, [DateTime? now]) => daysUntilDue(now) <= days;
}
