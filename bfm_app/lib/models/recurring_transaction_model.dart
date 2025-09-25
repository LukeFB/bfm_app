/// ---------------------------------------------------------------------------
/// File: recurring_transaction_model.dart
/// Author: [Your Name]
///
/// Purpose:
///   Model representing a recurring / expected payment. This feeds Alerts and
///   the "upcoming bills" UI. The model is intentionally minimal — date math
///   utilities live in services or small util helpers.
///
/// Fields:
///   id, category_id, amount, frequency ('weekly'|'monthly'), next_due_date,
///   description, created_at, updated_at
/// ---------------------------------------------------------------------------

class RecurringTransactionModel {
  final int? id;
  final int categoryId;
  final double amount;
  final String frequency; // 'weekly' | 'monthly' (extendable)
  final String nextDueDate; // YYYY-MM-DD
  final String? description;
  final String? createdAt;
  final String? updatedAt;

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

  /// Returns days until due from the provided `now` DateTime.
  int daysUntilDue([DateTime? now]) {
    final n = now ?? DateTime.now();
    try {
      final due = DateTime.parse(nextDueDate);
      return due.difference(DateTime(n.year, n.month, n.day)).inDays;
    } catch (_) {
      return 999999; // treat unknown as far in future
    }
  }

  /// Convenience: true if due within `days` (inclusive).
  bool isDueWithin(int days, [DateTime? now]) => daysUntilDue(now) <= days;
}
