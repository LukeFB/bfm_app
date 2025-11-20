/// ---------------------------------------------------------------------------
/// File: dashboard_screen.dart
/// Author: Luke Fraser-Brown
///
/// Budget header logic:
///   weeklyBudget = weeklyIncomeThisWeek − sum(weekly budgets)
///   leftToSpend  = weeklyBudget − discretionarySpendThisWeek
///
/// Where discretionary spend = expenses this week NOT in budgeted categories
/// (uncategorised counts as discretionary).
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/models/dash_data.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/utils/date_utils.dart';
import 'package:bfm_app/widgets/dashboard_card.dart';
import 'package:bfm_app/widgets/bottom_bar_button.dart';
import 'package:bfm_app/widgets/activity_item.dart';

import 'package:bfm_app/repositories/transaction_repository.dart';

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';

const Color bfmBlue = Color(0xFF005494); // TODO: make a themes file
const Color bfmOrange = Color(0xFFFF6934);
const Color bfmBeige = Color(0xFFF5F5E1);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashData> _load() async {
    await TransactionSyncService().syncIfStale();
    final results = await Future.wait([
    DashboardService.getDiscretionaryWeeklyBudget(), // uses last week's income
    DashboardService.discretionarySpendThisWeek(),   // Mon to today expenses
    DashboardService.getPrimaryGoal(),
    DashboardService.getAlerts(),
    TransactionRepository.getRecent(5),
    ]);

    final discWeeklyBudget = results[0] as double;
    final spentThisWeek  = results[1] as double;
    final goal = results[2] as GoalModel?;
    final alerts = results[3] as List<String>;
    final recent = results[4] as List<TransactionModel>;

    final leftToSpend = discWeeklyBudget - spentThisWeek;

    return DashData(
      leftToSpendThisWeek: leftToSpend,
      totalWeeklyBudget: discWeeklyBudget, // income - budgets
      primaryGoal: goal,
      alerts: alerts,
      recent: recent,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openRoute(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    _refresh();
  }

  /// Friendly, dynamic header based on how much is left this week.
  String _headerMessage(double left, double total) {
    if (total <= 0) {
      return "Let’s set up your budget and make a plan 🚀";
    }
    if (left < 0) {
      return "A tiny bit over — no stress. Fresh week, fresh start 💙";
    }
    final ratio = left / total; // 0.0 to 1.0
    if (ratio >= 0.75) return "Crushing it — plenty left this week 💪";
    if (ratio >= 0.50) return "You're on track! 🌟";
    if (ratio >= 0.25) return "You're doing fine — keep an eye on it 👀";
    if (ratio >= 0.10) return "Tight but doable — small choices win 💡";
    return "Almost tapped out — press pause on extras if you can ⏸️";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DashData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
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

            final data = snap.data!;
            final leftToSpendStr = "\$${data.leftToSpendThisWeek.toStringAsFixed(1)}";
            final weeklyBudgetStr = "Weekly budget: \$${data.totalWeeklyBudget.toStringAsFixed(0)}";

            final goalTitle = data.primaryGoal?.title ?? "Textbooks";
            final goalTarget = data.primaryGoal?.targetAmount ?? 200.0;
            final goalCurrent = data.primaryGoal?.currentAmount ?? (200.0 * 0.4);
            final goalProgress =
                goalTarget == 0 ? 0.0 : (goalCurrent / goalTarget).clamp(0.0, 1.0);
            final goalPercentLabel =
                "${(goalProgress * 100).toStringAsFixed(0)}% of \$${goalTarget.toStringAsFixed(0)} saved";

            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => _openRoute('/settings'),
                        ),
                      ],
                    ),
                    // ---------- HEADER ----------
                    Text(
                      _headerMessage(data.leftToSpendThisWeek, data.totalWeeklyBudget),
                      style: const TextStyle(
                        fontSize: 12,
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

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      onPressed: () => _openRoute('/budget/edit'),
                      label: const Text('Review / Edit weekly budget'),
                    ),

                    const SizedBox(height: 24),

                    // ---------- GOALS ----------
                    DashboardCard(
                      title: "Savings Goals",
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Open goals',
                        onPressed: () => _openRoute('/goals'),
                      ),
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
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'View all transactions',
                        onPressed: () => _openRoute('/transaction'),
                      ),
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
                            child: Text( // TODO: dynamic
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
                      title: "Financial Tip", // TODO: connect to backend api
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
                      title: "Upcoming Events", // TODO: connect to backend
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

      // -------------------- BOTTOM NAV --------------------
      bottomNavigationBar: SafeArea(
        child: Container(
          color: bfmBlue,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: BottomBarButton(
                  icon: Icons.insights,
                  label: "Insights",
                  onTap: () => _openRoute('/insights'),
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.account_balance_wallet,
                  label: "Budget",
                  onTap: () => _openRoute('/budget/edit'),
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.chat_bubble,
                  label: "Moni AI",
                  onTap: () => _openRoute('/chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
