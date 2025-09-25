/// ---------------------------------------------------------------------------
/// File: dash_data.dart
/// Author: Luke Fraser-Brown
/// Description:
///   Simple container model that groups together the core data needed
///   to render the dashboard screen. This is essentially a "view model"
///   that sits between raw DB queries and the UI layer.
///
/// Why:
///   Instead of passing around 4–5 unrelated values from the service layer
///   to the screen, we wrap them in a strongly-typed object. This ensures
///   consistency, makes testing easier, and prevents missing/extra params.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';

/// DashData is an immutable model that holds all dashboard-relevant
/// information in one place. This object is constructed in the service
/// layer (`DashboardService`) and consumed directly by the UI.
///
/// Fields:
/// - leftToSpendThisWeek: Amount remaining for the current week.
/// - totalWeeklyBudget: User’s planned weekly budget (sum of all categories).
/// - primaryGoal: The highest-priority savings goal, or null if none.
/// - alerts: List of time-sensitive notifications (e.g. bills due soon).
/// - recent: Recent transactions for quick activity display.
class DashData {
  final double leftToSpendThisWeek;
  final double totalWeeklyBudget;
  final GoalModel? primaryGoal;
  final List<String> alerts;
  final List<TransactionModel> recent;

  const DashData({
    required this.leftToSpendThisWeek,
    required this.totalWeeklyBudget,
    required this.primaryGoal,
    required this.alerts,
    required this.recent,
  });
}
