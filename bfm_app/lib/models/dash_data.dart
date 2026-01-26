/// ---------------------------------------------------------------------------
/// File: lib/models/dash_data.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   View model bundling everything the dashboard needs into one object.
///
/// Called by:
///   `dashboard_service.dart` (builder) and `dashboard_screen.dart` (consumer).
///
/// Inputs / Outputs:
///   Holds derived doubles, selected models, and string alerts ready for the
///   UI — no extra queries needed once this is constructed.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/services/budget_streak_service.dart';

/// Immutable snapshot of dashboard values for a render.
class DashData {
  final double leftToSpendThisWeek;
  final double totalWeeklyBudget;
  final GoalModel? primaryGoal;
  final List<GoalModel> allGoals;
  final List<AlertModel> alerts;
  final List<TransactionModel> recent;
  final TipModel? featuredTip;
  final List<EventModel> events;
  final BudgetStreakData budgetStreak;

  // Semi-circle chart data (optional, used by budgets screen)
  final double weeklyIncome;
  final double totalBudgeted;
  final double spentOnBudgets;
  final double discretionarySpent;

  /// Requires every piece of dashboard data up front to keep the UI simple.
  const DashData({
    required this.leftToSpendThisWeek,
    required this.totalWeeklyBudget,
    required this.primaryGoal,
    this.allGoals = const [],
    required this.alerts,
    required this.recent,
    required this.featuredTip,
    required this.events,
    required this.budgetStreak,
    this.weeklyIncome = 0.0,
    this.totalBudgeted = 0.0,
    this.spentOnBudgets = 0.0,
    this.discretionarySpent = 0.0,
  });
}
