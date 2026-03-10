import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bfm_app/utils/app_route_observer.dart';
import 'package:bfm_app/models/dash_data.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/utils/date_utils.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/tip_repository.dart';
import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/services/budget_streak_service.dart';
import 'package:bfm_app/services/content_sync_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_overview_sheet.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

class DashboardScreen extends StatefulWidget {
  final bool embedded;
  const DashboardScreen({super.key, this.embedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with RouteAware, AutomaticKeepAliveClientMixin {
  late Future<DashData> _future;
  DashData? _lastData;
  bool _weeklyOverviewCheckInFlight = false;
  CategoryEmojiHelper? _emojiHelper;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _initEmojiHelper();
  }

  Future<void> _initEmojiHelper() async {
    final helper = await CategoryEmojiHelper.ensureLoaded();
    if (mounted) setState(() => _emojiHelper = helper);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  Future<DashData> _load() async {
    _syncInBackground();
    final data = await _loadLocal();
    _scheduleWeeklyOverviewCheck();
    return data;
  }

  Future<void> _syncInBackground() async {
    var needsRefresh = false;
    try {
      final synced = await TransactionSyncService().syncIfStale();
      if (synced) needsRefresh = true;
    } catch (e) {
      debugPrint('Transaction sync: $e');
    }
    try {
      await ContentSyncService().syncDashboardContent();
      needsRefresh = true;
    } catch (e) {
      debugPrint('Content sync: $e');
    }
    if (needsRefresh && mounted) {
      setState(() => _future = _loadLocal());
    }
  }

  Future<DashData> _loadLocal() async {
    final results = await Future.wait([
      DashboardService.getWeeklyIncome(),
      DashboardService.getTotalBudgeted(),
      DashboardService.getSpentOnBudgets(),
      DashboardService.getTotalExpensesThisWeek(),
      GoalRepository.getSavingsGoals(),
      DashboardService.getAlerts(),
      TransactionRepository.getRecent(5),
      DashboardService.getFeaturedTip(),
      DashboardService.getUpcomingEvents(limit: 3),
      BudgetStreakService.calculateStreak(),
      DashboardService.getGoalBudgetTotal(),
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
    final goalBudgetTotal = results[10] as double;

    final budgetOverspend =
        (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
    final nonBudgetSpend =
        (totalExpenses - spentOnBudgets).clamp(0.0, double.infinity);
    final leftToSpend = weeklyIncome -
        totalBudgeted -
        goalBudgetTotal -
        budgetOverspend -
        nonBudgetSpend;

    return DashData(
      leftToSpendThisWeek: leftToSpend,
      totalWeeklyBudget: weeklyIncome - totalBudgeted - goalBudgetTotal,
      primaryGoal: allGoals.isNotEmpty ? allGoals.first : null,
      allGoals: allGoals,
      alerts: alerts,
      recent: recent,
      featuredTip: tip,
      events: events,
      budgetStreak: budgetStreak,
      weeklyIncome: weeklyIncome,
      totalBudgeted: totalBudgeted + goalBudgetTotal,
      spentOnBudgets: spentOnBudgets,
      discretionarySpent: nonBudgetSpend,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    setState(() => _future = _loadLocal());
  }

  Future<void> _openRoute(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    _refresh();
  }

  void _scheduleWeeklyOverviewCheck() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowWeeklyOverview());
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
              await WeeklyOverviewService.markOverviewHandled(
                  payload.weekStart);
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

  Future<void> _openSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: BuxlyColors.offWhite,
      body: SafeArea(
        child: FutureBuilder<DashData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              if (_lastData != null) return _buildContent(_lastData!);
              return const Center(
                child: CircularProgressIndicator(color: BuxlyColors.teal),
              );
            }
            if (snap.hasError) {
              if (_lastData != null) return _buildContent(_lastData!);
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

            _lastData = snap.data!;
            return _buildContent(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(DashData data) {
    return RefreshIndicator(
      color: BuxlyColors.teal,
      onRefresh: _forceSync,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _HeroCard(data: data),
            const SizedBox(height: 16),
            _AlertsGoalsRow(
              alerts: data.alerts,
              goals: data.allGoals,
              onAlertsPressed: () => _openRoute('/alerts/manage'),
              onGoalsPressed: () => _openRoute('/goals'),
            ),
            const SizedBox(height: 16),
            _RotatingTipCard(),
            const SizedBox(height: 16),
            _RecentActivityCard(
              transactions: data.recent,
              emojiHelper: _emojiHelper,
              onViewAll: () => _openRoute('/transaction'),
            ),
            if (data.events.isNotEmpty) ...[
              const SizedBox(height: 16),
              _EventsCard(events: data.events),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Health. Mental Wealth.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                SvgPicture.asset(
                  'assets/images/SVG/BUXLY LOGO_Horizontal_Wordmark_Light Turquoise.svg',
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    BuxlyColors.teal,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(
              Icons.settings_outlined,
              color: BuxlyColors.darkText,
            ),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Card
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final DashData data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isOverspent = data.leftToSpendThisWeek < 0;
    final income = data.weeklyIncome;
    final budgetOrSpent = data.spentOnBudgets > data.totalBudgeted
        ? data.spentOnBudgets
        : data.totalBudgeted;
    final weeklyLimit = (income - budgetOrSpent).clamp(0.0, double.infinity);
    final nonEssentialSpent = data.discretionarySpent;
    final progress =
        weeklyLimit > 0 ? (nonEssentialSpent / weeklyLimit).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: BuxlyColors.heroGradient,
        borderRadius: BorderRadius.circular(BuxlyRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Safe to spend on non-essentials',
                style: TextStyle(
                  fontSize: 14,
                  color: BuxlyColors.white.withOpacity(0.9),
                  fontFamily: BuxlyTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showExplanation(context),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: BuxlyColors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isOverspent ? '-' : ''}\$${data.leftToSpendThisWeek.abs().toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: BuxlyColors.white,
              fontFamily: BuxlyTheme.fontFamily,
              height: 1.1,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                label: 'Income',
                value: '\$${income.toStringAsFixed(0)}',
                color: BuxlyColors.limeGreen,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Budgeted',
                value: '\$${data.totalBudgeted.toStringAsFixed(0)}',
                color: BuxlyColors.coralOrange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(BuxlyRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: isOverspent
                  ? BuxlyColors.coralOrange
                  : BuxlyColors.white.withOpacity(0.9),
              backgroundColor: BuxlyColors.white.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% of non-essential spend used',
                style: TextStyle(
                  fontSize: 12,
                  color: BuxlyColors.white.withOpacity(0.8),
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
              Text(
                'Limit: \$${weeklyLimit.toStringAsFixed(0)}/wk',
                style: TextStyle(
                  fontSize: 12,
                  color: BuxlyColors.white.withOpacity(0.8),
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuxlyRadius.lg),
        ),
        title: const Text(
          'Safe to Spend',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: BuxlyTheme.fontFamily,
          ),
        ),
        content: const Text(
          'Your income minus your budgeted essentials minus what you\'ve '
          'already spent on non-essentials this week.\n\n'
          'Income − Budget − Non-essential spending\n= Safe to spend',
          style: TextStyle(
            fontSize: 14,
            fontFamily: BuxlyTheme.fontFamily,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(BuxlyRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BuxlyColors.white,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerts & Goals Row
// ---------------------------------------------------------------------------

class _AlertsGoalsRow extends StatelessWidget {
  final List<AlertModel> alerts;
  final List<GoalModel> goals;
  final VoidCallback onAlertsPressed;
  final VoidCallback onGoalsPressed;

  const _AlertsGoalsRow({
    required this.alerts,
    required this.goals,
    required this.onAlertsPressed,
    required this.onGoalsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Row(
        children: [
          Expanded(
            child: _AlertsCard(alerts: alerts, onPressed: onAlertsPressed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GoalsCard(goals: goals, onPressed: onGoalsPressed),
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<AlertModel> alerts;
  final VoidCallback onPressed;

  const _AlertsCard({required this.alerts, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Show standard and recurring alerts, exclude cancel-subscription
    final filtered = alerts
        .where((a) => a.type != AlertType.cancelSubscription)
        .toList()
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    final top2 = filtered.take(2).toList();

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BuxlyTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BuxlyColors.darkText,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 22, color: BuxlyColors.midGrey),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: top2.isEmpty
                  ? Center(
                      child: Text(
                        'No alerts',
                        style: TextStyle(
                          fontSize: 13,
                          color: BuxlyColors.midGrey,
                          fontFamily: BuxlyTheme.fontFamily,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: top2.map((alert) {
                        final icon = alert.icon ?? '🔔';
                        final dueLabel = _dueDateLabel(alert.dueDate, now);
                        final hasAmount =
                            alert.amount != null && alert.amount! > 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(icon,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: alert.isCancelSubscription
                                            ? BuxlyColors.coralOrange
                                            : BuxlyColors.darkText,
                                        fontFamily: BuxlyTheme.fontFamily,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (dueLabel.isNotEmpty ||
                                        hasAmount)
                                      Text(
                                        [
                                          if (dueLabel.isNotEmpty) dueLabel,
                                          if (hasAmount)
                                            '\$${alert.amount!.toStringAsFixed(0)}',
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: BuxlyColors.midGrey,
                                          fontFamily: BuxlyTheme.fontFamily,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _dueDateLabel(DateTime? dueDate, DateTime now) {
    if (dueDate == null) return '';
    final diff = dueDate.difference(now).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff <= 7) return '${diff}d left';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dueDate.month - 1]} ${dueDate.day}';
  }
}

class _GoalsCard extends StatelessWidget {
  final List<GoalModel> goals;
  final VoidCallback onPressed;

  const _GoalsCard({required this.goals, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BuxlyTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Goals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BuxlyColors.darkText,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 22, color: BuxlyColors.midGrey),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: goals.isEmpty
                  ? Center(
                      child: Text(
                        'Tap to create a savings goal!',
                        style: TextStyle(
                          fontSize: 13,
                          color: BuxlyColors.midGrey,
                          fontFamily: BuxlyTheme.fontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: goals.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final goal = goals[index];
                        final progress = goal.progressFraction;
                        final barColor = _goalColor(index);
                        final emoji = goalEmoji(goal);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(emoji,
                                    style:
                                        const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    goal.name.isEmpty
                                        ? 'Goal'
                                        : goal.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: BuxlyTheme.fontFamily,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            BuxlyProgressBar(
                              value: progress,
                              color: barColor,
                              height: 5,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${goal.savedAmount.toStringAsFixed(0)} / \$${goal.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: BuxlyColors.midGrey,
                                fontFamily: BuxlyTheme.fontFamily,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _goalColor(int index) {
    const colors = [
      BuxlyColors.teal,
      BuxlyColors.limeGreen,
      BuxlyColors.sunshineYellow,
      BuxlyColors.skyBlue,
    ];
    return colors[index % colors.length];
  }

}

// ---------------------------------------------------------------------------
// Rotating Tip Card — loads all tips and cycles through every 60s
// ---------------------------------------------------------------------------

class _RotatingTipCard extends StatefulWidget {
  const _RotatingTipCard();

  @override
  State<_RotatingTipCard> createState() => _RotatingTipCardState();
}

class _RotatingTipCardState extends State<_RotatingTipCard> {
  List<TipModel> _tips = [];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTips() async {
    final allTips = await TipRepository.getAllActive();
    if (!mounted || allTips.isEmpty) return;

    setState(() {
      _tips = allTips;
      _currentIndex = 0;
    });

    if (_tips.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _tips.length;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tips.isEmpty) return const SizedBox.shrink();

    final tip = _tips[_currentIndex];
    final body =
        tip.description?.isNotEmpty == true ? tip.description! : tip.title;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: BuxlyTipCard(
        key: ValueKey(tip.id ?? _currentIndex),
        title: 'Money tip of the day',
        body: body,
        icon: Icons.lightbulb_rounded,
        iconColor: BuxlyColors.coralOrange,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Activity
// ---------------------------------------------------------------------------

class _RecentActivityCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CategoryEmojiHelper? emojiHelper;
  final VoidCallback onViewAll;

  const _RecentActivityCard({
    required this.transactions,
    required this.emojiHelper,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewAll,
      child: BuxlyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: BuxlyColors.darkText,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: BuxlyColors.midGrey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity',
                  style: TextStyle(
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              )
            else
            ...transactions.map((t) {
              final isExpense = t.type == 'expense';
              final amt = isExpense ? -t.amount.abs() : t.amount.abs();
              final dateLabel = DateUtilsBFM.weekdayLabel(t.date);
              final emoji = _emojiForTransaction(t);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isExpense
                                ? BuxlyColors.coralOrange
                                : BuxlyColors.limeGreen)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.description.isEmpty
                            ? 'Transaction'
                            : t.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: BuxlyTheme.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${amt >= 0 ? '+' : '-'}\$${amt.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: amt >= 0
                                ? BuxlyColors.limeGreen
                                : BuxlyColors.darkText,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: BuxlyColors.midGrey,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _emojiForTransaction(TransactionModel t) {
    if (t.type == 'income') return '💰';
    if (emojiHelper == null) return CategoryEmojiHelper.defaultEmoji;

    // Try category name first; fall back to description if category
    // doesn't yield a specific match.
    if (t.categoryName != null && t.categoryName!.isNotEmpty) {
      final result = emojiHelper!.emojiForName(t.categoryName);
      if (result != CategoryEmojiHelper.defaultEmoji) return result;
    }
    return emojiHelper!.emojiForName(t.description);
  }
}

// ---------------------------------------------------------------------------
// Events Card
// ---------------------------------------------------------------------------

class _EventsCard extends StatelessWidget {
  final List<EventModel> events;
  const _EventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return BuxlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BuxlyColors.darkText,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < events.length; i++) ...[
            Row(
              children: [
                const BuxlyIconContainer(
                  icon: Icons.event_outlined,
                  color: BuxlyColors.skyBlue,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: BuxlyTheme.fontFamily,
                        ),
                      ),
                      if (events[i].description?.isNotEmpty == true)
                        Text(
                          events[i].description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: BuxlyColors.midGrey,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (events[i].endDate != null)
                  Text(
                    _shortDate(events[i].endDate!),
                    style: TextStyle(
                      fontSize: 12,
                      color: BuxlyColors.midGrey,
                      fontFamily: BuxlyTheme.fontFamily,
                    ),
                  ),
              ],
            ),
            if (i != events.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
