/// ---------------------------------------------------------------------------
/// File: lib/models/goal_progress_log.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents one weekly entry in the goal progress log table.
///
/// Called by:
///   `goal_repository.dart`, `insights_service.dart`, and `app_database.dart`
///   (for migrations/seeding).
///
/// Inputs / Outputs:
///   Converts SQLite rows to typed objects with convenience booleans.
/// ---------------------------------------------------------------------------
class GoalProgressLog {
  final int? id;
  final int goalId;
  final DateTime weekStart;
  final bool credited;
  final double amount;
  final String? note;
  final DateTime createdAt;

  /// Immutable record capturing how a goal performed for one week.
  const GoalProgressLog({
    this.id,
    required this.goalId,
    required this.weekStart,
    required this.credited,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  /// Hydrates from a SQLite map and converts status to a `credited` boolean.
  factory GoalProgressLog.fromMap(Map<String, dynamic> map) {
    return GoalProgressLog(
      id: map['id'] as int?,
      goalId: map['goal_id'] as int,
      weekStart: DateTime.parse(map['week_start'] as String),
      credited: ((map['status'] ?? '') as String).toLowerCase() == 'credited',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
      createdAt: DateTime.parse(
        (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

