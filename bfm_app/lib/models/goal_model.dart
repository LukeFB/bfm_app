/// ---------------------------------------------------------------------------
/// File: goal_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   A simple model representing a savings goal. This maps to the goals
///   table and is used by the dashboard's "Savings Goals" widget.
///
/// TODO: map goals to a budget via calculating weekly contribution.
/// ---------------------------------------------------------------------------

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

  double get progressFraction {
    if (amount <= 0) return 0.0;
    final fraction = savedAmount / amount;
    if (fraction.isNaN || fraction.isInfinite) return 0.0;
    return fraction.clamp(0.0, 1.0);
  }

  String progressLabel() => amount <= 0
      ? "\$${savedAmount.toStringAsFixed(0)} saved"
      : "\$${savedAmount.toStringAsFixed(0)} of \$${amount.toStringAsFixed(0)}";

  bool get isComplete => amount > 0 && savedAmount >= amount;
}
