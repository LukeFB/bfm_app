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
///   leftToSpend = income - budgeted - budgetOverspend - nonBudgetSpend
///
/// Where:
///   budgetOverspend = max(0, spentOnBudgets - totalBudgeted)
///   nonBudgetSpend = expenses this week NOT in budgeted categories
/// (uncategorised counts as non-budget spend).
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
import 'package:bfm_app/repositories/goal_repository.dart';

import 'package:bfm_app/repositories/transaction_repository.dart';

import 'package:bfm_app/models/alert_model.dart';
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
      DashboardService.getWeeklyIncome(), // Weekly income
      DashboardService.getTotalBudgeted(), // Sum of all budgets
      DashboardService.getSpentOnBudgets(), // Spent on budgeted categories
      DashboardService.getTotalExpensesThisWeek(), // Total expenses this week
      GoalRepository.getAll(), // All goals for the goals card
      DashboardService.getAlerts(),
      TransactionRepository.getRecent(5),
      DashboardService.getFeaturedTip(),
      DashboardService.getUpcomingEvents(limit: 3),
      BudgetStreakService.calculateStreak(),
    ]);

    final weeklyIncome = results[0] as double;
    final totalBudgeted = results[1] as double;
    final spentOnBudgets = results[2] as double;
    final totalExpenses = results[3] as double;
    final allGoals = results[4] as List<GoalModel>;
    final alerts = results[5] as List<AlertModel>;
    final recent = results[6] as List<TransactionModel>;
    final tip = results[7] as TipModel?;
    final events = results[8] as List<EventModel>;
    final budgetStreak = results[9] as BudgetStreakData;

    // Calculate left to spend: income - budgeted - budget overspend - non budget spend
    // This matches the formula used in the budget edit/review screen
    final budgetOverspend = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
    final nonBudgetSpend = (totalExpenses - spentOnBudgets).clamp(0.0, double.infinity);
    final leftToSpend = weeklyIncome - totalBudgeted - budgetOverspend - nonBudgetSpend;

    final data = DashData(
      leftToSpendThisWeek: leftToSpend,
      totalWeeklyBudget: weeklyIncome - totalBudgeted, // Discretionary budget (income - budgets)
      primaryGoal: allGoals.isNotEmpty ? allGoals.first : null,
      allGoals: allGoals,
      alerts: alerts,
      recent: recent,
      featuredTip: tip,
      events: events,
      budgetStreak: budgetStreak,
      weeklyIncome: weeklyIncome,
      totalBudgeted: totalBudgeted,
      spentOnBudgets: spentOnBudgets,
      discretionarySpent: nonBudgetSpend,
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

            final featuredTip = data.featuredTip;
            final upcomingEvents = data.events;
            final isOverspent = data.leftToSpendThisWeek < 0;

            return Column(
              children: [
                // ---------- STICKY TOP BAR ----------
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (data.budgetStreak.streakWeeks > 1)
                            Text(
                              '${data.budgetStreak.streakWeeks}🔥',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => _openRoute('/settings'),
                          ),
                        ],
                      ),
                      // ---------- MOTIVATIONAL MESSAGE ----------
                      Text(
                        _headerMessage(
                          data.leftToSpendThisWeek,
                          data.totalWeeklyBudget,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: "Roboto",
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // ---------- SCROLLABLE CONTENT ----------
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _forceSync,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---------- BIG LEFT TO SPEND FIGURE ----------
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '\$${data.leftToSpendThisWeek.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: isOverspent ? const Color(0xFFE53935) : bfmBlue,
                            ),
                          ),
                          Text(
                            isOverspent ? 'overspent this week' : 'left to spend this week',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- ALERTS AND GOALS SIDE BY SIDE ----------
                    SizedBox(
                      height: 160,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Alerts Card (Left)
                          Expanded(
                            child: _AlertsCard(
                              alerts: data.alerts,
                              onAlertsPressed: () => _openRoute('/alerts/manage'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Goals Card (Right)
                          Expanded(
                            child: _GoalsCard(
                              goals: data.allGoals,
                              onGoalsPressed: () => _openRoute('/goals'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 12),

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
                  ),
                ),
              ],
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
                  onTap: () => _openRoute('/budgets'),
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.savings_outlined,
                  label: "Savings",
                  onTap: () => _openRoute('/savings'),
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

/// Scrollable alerts card for the dashboard.
class _AlertsCard extends StatelessWidget {
  final List<AlertModel> alerts;
  final VoidCallback? onAlertsPressed;

  static const Color redOverspent = Color(0xFFE53935);

  const _AlertsCard({
    required this.alerts,
    this.onAlertsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sortedAlerts = List<AlertModel>.from(alerts)
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAlertsPressed,
                child: const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sortedAlerts.isEmpty
                ? const Center(
                    child: Text(
                      'No alerts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: sortedAlerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alert = sortedAlerts[index];
                      final daysLeft = alert.dueDate != null
                          ? alert.dueDate!.difference(now).inDays
                          : null;
                      final icon = alert.icon ?? '🔔';
                      final hasAmount = alert.amount != null && alert.amount! > 0;

                      String daysText = '';
                      if (daysLeft != null) {
                        daysText = daysLeft <= 0
                            ? 'Today'
                            : daysLeft == 1
                                ? '1d'
                                : '${daysLeft}d';
                      }

                      return GestureDetector(
                        onTap: onAlertsPressed,
                        child: Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alert.title,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasAmount) ...[
                              Text(
                                '\$${alert.amount!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (daysText.isNotEmpty)
                              Text(
                                daysText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (daysLeft ?? 999) <= 1 ? redOverspent : Colors.grey,
                                  fontWeight: (daysLeft ?? 999) <= 1 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable goals card for the dashboard.
class _GoalsCard extends StatelessWidget {
  final List<GoalModel> goals;
  final VoidCallback? onGoalsPressed;

  const _GoalsCard({
    required this.goals,
    this.onGoalsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Goals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onGoalsPressed,
                child: const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: GestureDetector(
                      onTap: onGoalsPressed,
                      child: const Text(
                        'Tap to create a savings goal!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      final progress = goal.progressFraction;
                      final isComplete = goal.isComplete;

                      return GestureDetector(
                        onTap: onGoalsPressed,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.name.isEmpty ? 'Goal' : goal.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isComplete)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              color: bfmBlue,
                              backgroundColor: Colors.grey.shade300,
                              minHeight: 6,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${goal.savedAmount.toStringAsFixed(0)} / \$${goal.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
