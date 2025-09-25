/// ---------------------------------------------------------------------------
/// File: goal_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   A simple model representing a savings goal. This maps to the `goals`
///   table and is used by the dashboard's "Savings Goals" widget.
///
/// Notes:
///   - The model contains small helpers for progress calculation but does not
///     perform DB updates itself. All updates should happen via the repository/service.
///   - Keep keys in toMap() aligned with the DB DDL (snake_case).
/// ---------------------------------------------------------------------------

class GoalModel {
  final int? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? dueDate; // YYYY-MM-DD or null
  final String status; // e.g. 'active', 'complete'

  const GoalModel({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.dueDate,
    required this.status,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as int?,
      title: (map['title'] ?? '') as String,
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: map['due_date'] as String?,
      status: (map['status'] as String?) ?? 'active',
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'due_date': dueDate,
      'status': status,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  /// Progress fraction between 0.0 and 1.0
  double progress() {
    if (targetAmount <= 0) return 0.0;
    final p = (currentAmount / targetAmount);
    if (p.isNaN || p.isInfinite) return 0.0;
    return p.clamp(0.0, 1.0);
  }

  /// Friendly percent label used in UI.
  String percentLabel() => "${(progress() * 100).toStringAsFixed(0)}% of \$${targetAmount.toStringAsFixed(0)} saved";

  bool get isComplete => progress() >= 1.0;
}
