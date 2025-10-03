/// ---------------------------------------------------------------------------
/// File: dashboard_screen.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   This is the main landing page of the BFM app. It pulls together
///   financial data from multiple sources (budgets, goals, transactions,
///   recurring bills) and presents them as a dashboard.
///
/// Design philosophy:
///   - Keep UI layout and data-loading concerns separate.
///     -> Database queries live in `DashboardService`.
///     -> Models are defined in `DashData` and other classes.
///     -> Widgets (cards, buttons, activity items) are imported here.
///
///   - State management is kept lightweight with `FutureBuilder` and
///     `setState` because this screen is refresh-based and does not
///     need fine-grained reactivity.
///
///   - Visual design is card-based, with distinct sections for budgets,
///     goals, alerts, activity, streaks, tips, and events.
///
/// Future scope:
///   - Replace FutureBuilder + setState with a state management
///     solution (e.g. Riverpod, Bloc) if complexity grows.
///   - Make alerts, tips, and events dynamic from DB instead of static.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/models/dash_data.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/utils/date_utils.dart';
import 'package:bfm_app/widgets/dashboard_card.dart';
import 'package:bfm_app/widgets/bottom_bar_button.dart';
import 'package:bfm_app/widgets/activity_item.dart';

import 'package:bfm_app/repositories/transaction_repository.dart';

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';

/// Brand colors used throughout the app. These constants
/// centralize color definitions for consistency.
const Color bfmBlue = Color(0xFF005494);
const Color bfmOrange = Color(0xFFFF6934);
const Color bfmBeige = Color(0xFFF5F5E1);

/// ---------------------------------------------------------------------------
/// DashboardScreen
/// ---------------------------------------------------------------------------
/// StatefulWidget because:
///   - We need to hold a Future in state (`_future`) to avoid re-triggering
///     DB queries every rebuild.
///   - We refresh data after navigation actions (e.g. when a new
///     transaction is added).
///
/// Lifecycle:
///   - initState(): load initial dashboard data.
///   - _refresh(): trigger reload on pull-to-refresh or return from routes.
/// ---------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// The dashboard data future. This is cached and re-assigned
  /// only when `_refresh` is explicitly called.
  late Future<DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(); // kick off initial load
  }

  /// Fetches and aggregates all dashboard data from services.
  ///
  /// Loads in parallel via Future.wait:
  ///   0: Total weekly budget
  ///   1: Expenses for current week
  ///   2: Primary goal
  ///   3: Alerts
  ///   4: Recent transactions
  ///
  /// Returns a DashData object that wraps everything for easy use in UI.
  Future<DashData> _load() async {
    final results = await Future.wait([
      DashboardService.getTotalWeeklyBudgetSafe(),
      DashboardService.getThisWeekExpenses(),
      DashboardService.getPrimaryGoal(),
      DashboardService.getAlerts(),
      TransactionRepository.getRecent(5),
    ]);

    final totalWeekly = results[0] as double;
    final spentThisWeek = results[1] as double;
    final goal = results[2] as GoalModel?;
    final alerts = results[3] as List<String>;
    final recent = results[4] as List<TransactionModel>;

    return DashData(
      leftToSpendThisWeek: (totalWeekly - spentThisWeek),
      totalWeeklyBudget: totalWeekly,
      primaryGoal: goal,
      alerts: alerts,
      recent: recent,
    );
  }

  /// Triggers a full reload of the dashboard data.
  /// Called by pull-to-refresh gestures and after returning from
  /// other routes (transactions, goals, etc).
  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // -------------------- BODY --------------------
      body: SafeArea(
        child: FutureBuilder<DashData>(
          future: _future,
          builder: (context, snap) {
            // Loading state: show spinner
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error state: render error message visibly
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Error loading dashboard:\n${snap.error}",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Success: snapshot contains data
            final data = snap.data!;

            // Pre-format numbers for display
            final leftToSpendStr = "\$${data.leftToSpendThisWeek.toStringAsFixed(1)}";
            final weeklyBudgetStr = "Weekly budget: \$${data.totalWeeklyBudget.toStringAsFixed(0)}";

            // Goal progress calculation with fallbacks
            final goalTitle = data.primaryGoal?.title ?? "Textbooks";
            final goalTarget = data.primaryGoal?.targetAmount ?? 200.0;
            final goalCurrent = data.primaryGoal?.currentAmount ?? (200.0 * 0.4);
            final goalProgress = goalTarget == 0 ? 0.0 : (goalCurrent / goalTarget).clamp(0.0, 1.0);
            final goalPercentLabel =
                "${(goalProgress * 100).toStringAsFixed(0)}% of \$${goalTarget.toStringAsFixed(0)} saved";

            // Main scrollable dashboard content
            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- HEADER ----------
                    const Text(
                      "You're on track!",
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: "Roboto",
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      leftToSpendStr,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: bfmBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Left to spend"),
                        Text(weeklyBudgetStr),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ---------- GOALS ----------
                    DashboardCard(
                      title: "Savings Goals",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goalTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: goalProgress,
                            color: bfmBlue,
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(goalPercentLabel),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- ALERTS ----------
                    DashboardCard(
                      title: "Alerts",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: data.alerts
                            .map((msg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(msg),
                                ))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- RECENT ACTIVITY ----------
                    DashboardCard(
                      title: "Recent Activity",
                      child: Column(
                        children: data.recent.map((t) {
                          final date = DateUtilsBFM.weekdayLabel(t.date);
                          final amt = (t.type == 'expense')
                              ? -t.amount.abs()
                              : t.amount.abs();
                          return ActivityItem(
                            label: t.description.isEmpty ? "Transaction" : t.description,
                            amount: amt,
                            date: date,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- STREAKS ----------
                    const DashboardCard(
                      title: "Streaks",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              "🔥3",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "You have opened the app 3 weeks in a row",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- FINANCIAL TIP ----------
                    const DashboardCard(
                      title: "Financial Tip",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "💡 Cook in bulk: Preparing meals ahead can save up to \$30 per week.",
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- EVENTS ----------
                    const DashboardCard(
                      title: "Upcoming Events",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("🎓 Orientation – Free sausage sizzle - in 2 days"),
                          SizedBox(height: 8),
                          Text("🥪 Food bank visit - Free food in room 1 - in 5 days"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      // -------------------- BOTTOM NAVIGATION --------------------
      bottomNavigationBar: SafeArea(
        child: Container(
          color: bfmBlue,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: BottomBarButton(
                  icon: Icons.add,
                  label: "Transaction",
                  onTap: () async {
                    await Navigator.pushNamed(context, '/transaction');
                    if (!mounted) return;
                    _refresh(); // always refresh after returning
                  },
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.insights,
                  label: "Insights",
                  onTap: () async {
                    await Navigator.pushNamed(context, '/insights');
                    if (!mounted) return;
                    _refresh();
                  },
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.flag,
                  label: "Goals",
                  onTap: () async {
                    final changed = await Navigator.pushNamed(context, '/goals');
                    if (!mounted) return;
                    _refresh(); // refresh regardless of returned flag
                  },
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.chat_bubble,
                  label: "Moni AI",
                  onTap: () async {
                    await Navigator.pushNamed(context, '/chat');
                    if (!mounted) return;
                    _refresh();
                  },
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.settings,
                  label: "settings",
                  onTap: () async {
                    await Navigator.pushNamed(context, '/settings');
                    if (!mounted) return;
                    _refresh(); // refresh regardless of returned flag
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
