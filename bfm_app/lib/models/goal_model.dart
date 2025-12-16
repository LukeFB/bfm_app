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

/// Represents a savings goal with progress tracking.
class GoalModel {
  final int? id;
  final String name;
  final double amount;
  final double weeklyContribution;
  final double savedAmount;

  const GoalModel({
    this.id,
    required this.name,
    required this.amount,
    required this.weeklyContribution,
    this.savedAmount = 0,
  });

  /// Creates a goal from DB/JSON maps. Handles legacy columns gracefully.
  factory GoalModel.fromMap(Map<String, dynamic> map) {
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
    );
  }

  /// Serialises for inserts/updates, optionally including the primary key.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'name': name,
      'amount': amount,
      'weekly_contribution': weeklyContribution,
      'saved_amount': savedAmount,
    };
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
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      weeklyContribution: weeklyContribution ?? this.weeklyContribution,
      savedAmount: savedAmount ?? this.savedAmount,
    );
  }

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
