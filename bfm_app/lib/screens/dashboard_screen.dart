// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:bfm_app/db/database.dart';

// brand colors — unchanged
const Color bfmBlue = Color(0xFF005494);
const Color bfmOrange = Color(0xFFFF6934);
const Color bfmBeige = Color(0xFFF5F5E1);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future; // cache the future so FutureBuilder reloads only when we say so

  @override
  void initState() {
    super.initState();
    _future = _load(); // first load
  }

  // ----------------- data loaders -----------------
  Future<double> _getTotalWeeklyBudget() async {
    final total = await getTotalWeeklyBudget();
    return total.isNaN ? 0.0 : total;
  }

  Future<double> _getThisWeekExpenses() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday
    String _fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final start = _fmt(startOfWeek);
    final end = _fmt(now);

    final res = await db.rawQuery('''
      SELECT SUM(amount) AS spent
      FROM transactions
      WHERE type = 'expense'
        AND date BETWEEN ? AND ?
    ''', [start, end]);

    final raw = (res.isNotEmpty ? res.first['spent'] : null);
    final value = (raw is num) ? raw.toDouble() : 0.0;
    return value.abs();
  }

  Future<GoalModel?> _getPrimaryGoal() async {
    final goals = await getGoals();
    return goals.isEmpty ? null : goals.first;
  }

  Future<List<String>> _getAlerts() async {
    final db = await AppDatabase.instance.database;
    final today = DateTime.now();
    final soon = today.add(const Duration(days: 7));

    final rows = await db.query(
      'recurring_transactions',
      columns: ['description', 'next_due_date', 'amount'],
    );

    final List<String> alerts = [];
    for (final r in rows) {
      final desc = (r['description'] ?? 'Bill') as String;
      final amt = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;
      final dueStr = r['next_due_date'] as String?;
      if (dueStr == null || dueStr.trim().isEmpty) continue;
      DateTime? due;
      try { due = DateTime.parse(dueStr); } catch (_) { continue; }
      final days = due.difference(today).inDays;
      if (days >= 0 && due.isBefore(soon)) {
        alerts.add("⚠️ $desc (\$${amt.toStringAsFixed(0)}) due in $days day${days == 1 ? '' : 's'}");
      }
    }
    if (alerts.isEmpty) {
      return const [
        "👉 You spent \$30 on Fortnite last month",
        "💡 StudyLink payment due in 3 days",
        "⚠️ Phone bill due in 4 days",
      ];
    }
    return alerts;
  }

  Future<_DashData> _load() async {
    final results = await Future.wait([
      _getTotalWeeklyBudget(),  // 0
      _getThisWeekExpenses(),   // 1
      _getPrimaryGoal(),        // 2
      _getAlerts(),             // 3
      getRecentTransactions(5), // 4
    ]);

    final totalWeekly = results[0] as double;
    final spentThisWeek = results[1] as double;
    final goal = results[2] as GoalModel?;
    final alerts = results[3] as List<String>;
    final recent = results[4] as List<TransactionModel>;

    return _DashData(
      leftToSpendThisWeek: (totalWeekly - spentThisWeek),
      totalWeeklyBudget: totalWeekly,
      primaryGoal: goal,
      alerts: alerts,
      recent: recent,
    );
  }

  // helper
  String _weekdayLabel(String ymd) {
    try {
      final d = DateTime.parse(ymd);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    } catch (_) {
      return ymd;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(); // trigger FutureBuilder to refetch
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_DashData>(
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
            final goalProgress = goalTarget == 0 ? 0.0 : (goalCurrent / goalTarget).clamp(0.0, 1.0);
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

                    // ---------- GOALS SNAPSHOT ----------
                    _DashboardCard(
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
                    _DashboardCard(
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
                    _DashboardCard(
                      title: "Recent Activity",
                      child: Column(
                        children: data.recent.map((t) {
                          final date = _weekdayLabel(t.date);
                          final amt = (t.type == 'expense')
                              ? -t.amount.abs()
                              : t.amount.abs();
                          return _ActivityItem(
                            label: t.description.isEmpty ? "Transaction" : t.description,
                            amount: amt,
                            date: date,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- STREAKS / TIP / EVENTS TODO ----------
                    const _DashboardCard(
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
                            "You have stayed under budget 3 weeks in a row",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const _DashboardCard(
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

                    const _DashboardCard(
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

      // ---------- BOTTOM BAR ----------
      bottomNavigationBar: SafeArea(
        child: Container(
          color: bfmBlue,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _BottomBarButton(
                  icon: Icons.add,
                  label: "Transactions",
                  onTap: () async {
                    // Wait for the route to return, then refresh
                    await Navigator.pushNamed(context, '/transaction');
                    if (!mounted) return;
                    _refresh();
                  },
                ),
              ),
              Expanded(
                child: _BottomBarButton(
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
                child: _BottomBarButton(
                  icon: Icons.flag,
                  label: "Goals",
                  onTap: () async {
                    final changed = await Navigator.pushNamed(context, '/goals');
                    if (!mounted) return;
                    // If goals changed, or just in case, refresh
                    if (changed == true) {
                      _refresh();
                    } else {
                      _refresh(); // Always refresh on return
                    }
                  },
                ),
              ),
              Expanded(
                child: _BottomBarButton(
                  icon: Icons.chat_bubble,
                  label: "Moni AI",
                  onTap: () async {
                    await Navigator.pushNamed(context, '/chat');
                    if (!mounted) return;
                    _refresh();
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

// helper types/widgets
class _DashData {
  final double leftToSpendThisWeek;
  final double totalWeeklyBudget;
  final GoalModel? primaryGoal;
  final List<String> alerts;
  final List<TransactionModel> recent;
  _DashData({
    required this.leftToSpendThisWeek,
    required this.totalWeeklyBudget,
    required this.primaryGoal,
    required this.alerts,
    required this.recent,
  });
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashboardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap; // make it async-friendly
  const _BottomBarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // await handled in caller
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String label;
  final double amount;
  final String date;
  const _ActivityItem({required this.label, required this.amount, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text("\$${amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: amount < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              )),
          Text(date, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
