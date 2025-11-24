class GoalProgressLog {
  final int? id;
  final int goalId;
  final DateTime weekStart;
  final bool credited;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const GoalProgressLog({
    this.id,
    required this.goalId,
    required this.weekStart,
    required this.credited,
    required this.amount,
    this.note,
    required this.createdAt,
  });

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

