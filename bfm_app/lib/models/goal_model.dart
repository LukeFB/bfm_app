/// ---------------------------------------------------------------------------
/// File: lib/models/goal_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Goal repository, dashboard, and goals screen components.
///
/// Purpose:
///   - Typed view over the goals table including legacy column fallbacks so we
///     can display and update savings progress reliably.
///
/// Inputs:
///   - SQLite rows (with possible legacy fields) or JSON from sync.
///
/// Outputs:
///   - Dart object plus helper maps/labels for the UI.
///
/// Notes:
///   - TODO: map goals to a budget via calculating weekly contribution.
/// ---------------------------------------------------------------------------

/// Goal types to distinguish regular savings from recovery goals.
enum GoalType {
  savings,
  recovery,
}

/// Represents a savings or recovery goal with progress tracking.
class GoalModel {
  final int? id;
  final String name;
  final double amount;
  final double weeklyContribution;
  final double savedAmount;
  
  /// Type of goal: 'savings' for regular goals, 'recovery' for deficit recovery.
  final GoalType goalType;
  
  /// For recovery goals: the original deficit amount that triggered creation.
  /// Stored for historical reference even after partial repayment.
  final double? originalDeficit;
  
  /// For recovery goals: number of weeks user chose to pay back over.
  final int? recoveryWeeks;

  const GoalModel({
    this.id,
    required this.name,
    required this.amount,
    required this.weeklyContribution,
    this.savedAmount = 0,
    this.goalType = GoalType.savings,
    this.originalDeficit,
    this.recoveryWeeks,
  });

  /// Creates a goal from DB/JSON maps. Handles legacy columns gracefully.
  factory GoalModel.fromMap(Map<String, dynamic> map) {
    // Parse goal_type with fallback to 'savings' for legacy rows
    final typeStr = (map['goal_type'] as String?) ?? 'savings';
    final goalType = typeStr == 'recovery' ? GoalType.recovery : GoalType.savings;
    
    return GoalModel(
      id: map['id'] as int?,
      name: (map['name'] ??
              map['title'] ?? // fallback for legacy rows
              '') as String,
      amount: (map['amount'] ??
              map['target_amount'] ??
              0) is num
          ? ((map['amount'] ?? map['target_amount']) as num).toDouble()
          : 0.0,
      weeklyContribution: (map['weekly_contribution'] ??
              map['current_amount'] ??
              0) is num
          ? ((map['weekly_contribution'] ?? map['current_amount']) as num)
              .toDouble()
          : 0.0,
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0.0,
      goalType: goalType,
      originalDeficit: (map['original_deficit'] as num?)?.toDouble(),
      recoveryWeeks: map['recovery_weeks'] as int?,
    );
  }

  /// Serialises for inserts/updates, optionally including the primary key.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'name': name,
      'amount': amount,
      'weekly_contribution': weeklyContribution,
      'saved_amount': savedAmount,
      'goal_type': goalType == GoalType.recovery ? 'recovery' : 'savings',
    };
    if (originalDeficit != null) m['original_deficit'] = originalDeficit;
    if (recoveryWeeks != null) m['recovery_weeks'] = recoveryWeeks;
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  /// Immutably copies the model with overrides, used by editing flows.
  GoalModel copyWith({
    int? id,
    String? name,
    double? amount,
    double? weeklyContribution,
    double? savedAmount,
    GoalType? goalType,
    double? originalDeficit,
    int? recoveryWeeks,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      weeklyContribution: weeklyContribution ?? this.weeklyContribution,
      savedAmount: savedAmount ?? this.savedAmount,
      goalType: goalType ?? this.goalType,
      originalDeficit: originalDeficit ?? this.originalDeficit,
      recoveryWeeks: recoveryWeeks ?? this.recoveryWeeks,
    );
  }
  
  /// True if this is a recovery goal for deficit payback.
  bool get isRecoveryGoal => goalType == GoalType.recovery;

  /// Returns a 0–1 fraction showing how far along the goal is.
  double get progressFraction {
    if (amount <= 0) return 0.0;
    final fraction = savedAmount / amount;
    if (fraction.isNaN || fraction.isInfinite) return 0.0;
    return fraction.clamp(0.0, 1.0);
  }

  /// User-facing string summarising saved vs total.
  String progressLabel() => amount <= 0
      ? "\$${savedAmount.toStringAsFixed(0)} saved"
      : "\$${savedAmount.toStringAsFixed(0)} of \$${amount.toStringAsFixed(0)}";

  /// True once the saved amount meets/exceeds the target.
  bool get isComplete => amount > 0 && savedAmount >= amount;
}
