/// ---------------------------------------------------------------------------
/// File: lib/screens/dashboard_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/dashboard` route (main entry after LockGate).
///
/// Purpose:
///   - Aggregates and displays the user's weekly budget, alerts, goals, tips,
///     events, and recent transactions in one scrollable surface.
///
/// Inputs:
///   - Fetches data via `DashboardService`, `TransactionRepository`, and
///     `ContentSyncService`.
///
/// Outputs:
///   - UI summarising money health plus navigation entry points.
///
/// Budget header logic:
///   weeklyBudget = weeklyIncomeThisWeek − sum(weekly budgets)
///   leftToSpend  = weeklyBudget − discretionarySpendThisWeek
///
/// Where discretionary spend = expenses this week NOT in budgeted categories
/// (uncategorised counts as discretionary).
/// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:bfm_app/utils/app_route_observer.dart';
import 'package:bfm_app/models/dash_data.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/utils/date_utils.dart';
import 'package:bfm_app/widgets/dashboard_card.dart';
import 'package:bfm_app/widgets/bottom_bar_button.dart';
import 'package:bfm_app/widgets/activity_item.dart';

import 'package:bfm_app/repositories/transaction_repository.dart';

import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/services/budget_streak_service.dart';
import 'package:bfm_app/services/content_sync_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_overview_sheet.dart';

const Color bfmBlue = Color(0xFF005494); // TODO: make a themes file
const Color bfmOrange = Color(0xFFFF6934);
const Color bfmBeige = Color(0xFFF5F5E1);

/// Home surface summarising budgets, goals, alerts, and recent activity.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Manages refresh logic, route awareness, and UI helpers for dashboard data.
class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  late Future<DashData> _future;
  bool _weeklyOverviewCheckInFlight = false;

  /// Bootstraps the dashboard load as soon as the widget mounts.
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Subscribes to route observer so we can refresh when returning to the tab.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  /// Unsubscribes from the route observer.
  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Refresh when returning from another screen (e.g., budget edit) so totals update.
  @override
  void didPopNext() {
    _refresh();
  }

  /// Syncs transactions/content when stale and composes the `DashData` bundle.
  Future<DashData> _load() async {
    await TransactionSyncService().syncIfStale();
    try {
      await ContentSyncService().syncDashboardContent();
    } catch (err) {
      debugPrint('Content sync skipped: $err');
    }
    final results = await Future.wait([
      DashboardService.getDiscretionaryWeeklyBudget(), // recurring income (fallback: last week)
      DashboardService.discretionarySpendThisWeek(), // Mon to today expenses
      DashboardService.getPrimaryGoal(),
      DashboardService.getAlerts(),
      TransactionRepository.getRecent(5),
      DashboardService.getFeaturedTip(),
      DashboardService.getUpcomingEvents(limit: 3),
      BudgetStreakService.calculateStreak(),
    ]);

    final discWeeklyBudget = results[0] as double;
    final spentThisWeek = results[1] as double;
    final goal = results[2] as GoalModel?;
    final alerts = results[3] as List<String>;
    final recent = results[4] as List<TransactionModel>;
    final tip = results[5] as TipModel?;
    final events = results[6] as List<EventModel>;
    final budgetStreak = results[7] as BudgetStreakData;

    final leftToSpend = discWeeklyBudget - spentThisWeek;

    final data = DashData(
      leftToSpendThisWeek: leftToSpend,
      totalWeeklyBudget: discWeeklyBudget, // income - budgets
      primaryGoal: goal,
      alerts: alerts,
      recent: recent,
      featuredTip: tip,
      events: events,
      budgetStreak: budgetStreak,
    );
    _scheduleWeeklyOverviewCheck();
    return data;
  }

  /// Triggers a rebuild by swapping the Future (uses stale check).
  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  /// Force syncs transactions immediately (bypasses stale check).
  /// Used for pull-to-refresh when user wants latest data NOW.
  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  /// Pushes a named route and refreshes the dashboard after returning.
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
      return "Slightly over — no stress. Fresh week, fresh start";
    }
    final ratio = left / total; // 0.0 to 1.0
    if (ratio >= 0.75) return "Crushing it — plenty left this week 💪";
    if (ratio >= 0.50) return "You're on track! 🌟";
    if (ratio >= 0.25) return "You're doing fine — keep an eye on it 👀";
    if (ratio >= 0.10) return "Tight but doable — small choices win 💡";
    return "Almost tapped out — press pause on extras if you can ⏸️";
  }

  /// Tiny helper for "Apr 12" style date labels.
  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}';
  }

  void _scheduleWeeklyOverviewCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWeeklyOverview();
    });
  }

  Future<void> _maybeShowWeeklyOverview() async {
    if (_weeklyOverviewCheckInFlight || !mounted) return;
    _weeklyOverviewCheckInFlight = true;
    try {
      final payload = await WeeklyOverviewService.buildPayloadIfEligible();
      if (payload == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WeeklyOverviewSheet(
            payload: payload,
            onFinish: () async {
              await WeeklyOverviewService.markOverviewHandled(payload.weekStart);
              if (!mounted) return;
              await _refresh();
            },
          ),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _weeklyOverviewCheckInFlight = false;
    }
  }

  /// Renders the scrollable dashboard plus bottom navigation.
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
            final leftToSpendStr =
                "\$${data.leftToSpendThisWeek.toStringAsFixed(1)}";
            final weeklyBudgetStr =
                "Weekly budget: \$${data.totalWeeklyBudget.toStringAsFixed(0)}";

            final primaryGoal = data.primaryGoal;
            final goalName =
                (primaryGoal == null || primaryGoal.name.trim().isEmpty)
                ? "Savings goal"
                : primaryGoal.name;
            final goalAmount = primaryGoal?.amount ?? 0.0;
            final savedAmount = primaryGoal?.savedAmount ?? 0.0;
            final goalProgress = primaryGoal?.progressFraction ?? 0.0;
            final featuredTip = data.featuredTip;
            final upcomingEvents = data.events;

            return RefreshIndicator(
              onRefresh: _forceSync,
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
                      _headerMessage(
                        data.leftToSpendThisWeek,
                        data.totalWeeklyBudget,
                      ),
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
                          Text(
                            goalName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (goalAmount > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: goalProgress,
                                  color: bfmBlue,
                                  backgroundColor: Colors.grey.shade300,
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "\$${savedAmount.toStringAsFixed(0)} / \$${goalAmount.toStringAsFixed(0)} saved",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              "Click the arrow to set your first goal.",
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- ALERTS ----------
                    DashboardCard(
                      title: "Alerts",
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Manage alerts',
                        onPressed: () => _openRoute('/alerts/manage'),
                      ),
                      child: data.alerts.isEmpty
                          ? const Text(
                              "No alerts yet. Tap the arrow to add reminders.",
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: data.alerts
                                  .map(
                                    (msg) {
                                      final cleaned =
                                          msg.replaceAll('(tap to review)', '').trim();
                                      final displayMsg = cleaned.isEmpty
                                          ? 'Reminder saved for this bill.'
                                          : cleaned;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Text(displayMsg),
                                      );
                                    },
                                  )
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...data.recent.map((t) {
                            final date = DateUtilsBFM.weekdayLabel(t.date);
                            final amt = (t.type == 'expense')
                                ? -t.amount.abs()
                                : t.amount.abs();
                            return ActivityItem(
                              label: t.description.isEmpty
                                  ? "Transaction"
                                  : t.description,
                              amount: amt,
                              date: date,
                              excluded: t.excluded,
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- STREAKS ----------
                    DashboardCard(
                      title: "Budget Streak",
                      child: data.budgetStreak.streakWeeks > 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    "🔥${data.budgetStreak.streakWeeks}",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "You have met your budget ${data.budgetStreak.streakWeeks} ${data.budgetStreak.streakWeeks == 1 ? 'week' : 'weeks'} in a row",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "You have saved: \$${data.budgetStreak.totalSaved.toStringAsFixed(data.budgetStreak.totalSaved >= 100 ? 0 : 2)}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    "🔥0",
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Complete a week under budget to start your streak!",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- FINANCIAL TIP ----------
                    DashboardCard(
                      title: "Financial Tip",
                      child: featuredTip == null
                          ? const Text(
                              "No curated tips yet — connect to Wi-Fi to grab the latest advice.",
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  featuredTip.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  featuredTip.expiresAt != null
                                      ? 'Ends ${_formatShortDate(featuredTip.expiresAt!)}'
                                      : 'No finish date set',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- EVENTS ----------
                    DashboardCard(
                      title: "Upcoming Events",
                      child: upcomingEvents.isEmpty
                          ? const Text(
                              "No upcoming campus events right now. Check back soon!",
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  int i = 0;
                                  i < upcomingEvents.length;
                                  i++
                                ) ...[
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        upcomingEvents[i].title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        upcomingEvents[i].endDate != null
                                            ? 'Ends ${_formatShortDate(upcomingEvents[i].endDate!)}'
                                            : 'No finish date set',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i != upcomingEvents.length - 1)
                                    const SizedBox(height: 12),
                                ],
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
