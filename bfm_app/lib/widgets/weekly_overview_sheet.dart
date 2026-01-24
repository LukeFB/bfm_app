import 'package:flutter/material.dart';

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/weekly_report_widgets.dart';

/// Full-screen modal that surfaces the previous week's insights plus goal actions.
class WeeklyOverviewSheet extends StatefulWidget {
  final WeeklyOverviewPayload payload;
  final Future<void> Function()? onFinish;

  const WeeklyOverviewSheet({
    super.key,
    required this.payload,
    this.onFinish,
  });

  @override
  State<WeeklyOverviewSheet> createState() => _WeeklyOverviewSheetState();
}

class _WeeklyOverviewSheetState extends State<WeeklyOverviewSheet> {
  late WeeklyOverviewPayload _payload;
  final Map<int, TextEditingController> _amountControllers = {};
  final Set<int> _selectedGoalIds = {};
  bool _submitting = false;
  double get _baseLeftToSpend => _payload.summary.discretionaryLeft;

  double get _selectedContributionTotal {
    double total = 0;
    for (final id in _selectedGoalIds) {
      total += _amountForGoal(id);
    }
    return total;
  }

  double get _visibleLeftToSpend => _baseLeftToSpend - _selectedContributionTotal;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
    _seedControllers();
    _autoSelectGoals(emitSetState: false);
  }

  void _seedControllers() {
    _disposeControllers();
    for (final goal in _payload.goals) {
      final id = goal.id;
      if (id == null) continue;
      final initial = _defaultContributionForGoal(goal);
      final decimals = initial % 1 == 0 ? 0 : 2;
      final controller =
          TextEditingController(text: initial.toStringAsFixed(decimals));
      controller.addListener(_handleContributionAmountChanged);
      _amountControllers[id] = controller;
    }
  }

  void _disposeControllers() {
    for (final controller in _amountControllers.values) {
      controller.removeListener(_handleContributionAmountChanged);
      controller.dispose();
    }
    _amountControllers.clear();
  }

  void _autoSelectGoals({bool emitSetState = true}) {
    void applySelection() {
      _selectedGoalIds.clear();
      final ids = _payload.goals.map((g) => g.id).whereType<int>().toList();
      if (ids.isEmpty) return;
      final total =
          ids.fold<double>(0, (sum, id) => sum + _amountForGoal(id));
      if (total <= _baseLeftToSpend + 0.01) {
        _selectedGoalIds.addAll(ids);
      }
    }

    if (emitSetState && mounted) {
      setState(applySelection);
    } else {
      applySelection();
    }
  }

  double _defaultContributionForGoal(GoalModel goal) =>
      goal.weeklyContribution > 0 ? goal.weeklyContribution : 10.0;

  double _amountForGoal(int id) {
    final controller = _amountControllers[id];
    final text = controller?.text ?? '';
    final parsed = double.tryParse(text.replaceAll(',', ''));
    if (parsed != null && parsed > 0) return parsed;
    final goal =
        _payload.goals.firstWhere((g) => g.id == id, orElse: () => const GoalModel(id: null, name: '', amount: 0, weeklyContribution: 0));
    if (goal.id == null) return 0;
    return _defaultContributionForGoal(goal);
  }

  void _handleContributionAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _payload.summary;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final encouragement =
        _encouragementMessage(_visibleLeftToSpend, summary.weeklyBudget);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Weekly overview'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                _formatRange(summary.weekStart, summary.weekEnd),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsets),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverviewStats(
                      weeklyBudget: summary.weeklyBudget,
                      leftToSpend: _visibleLeftToSpend,
                      encouragement: encouragement,
                    ),
                    const SizedBox(height: 16),
                    BudgetRingCard(
                      report: _payload.report,
                      showStats: false,
                    ),
                    const SizedBox(height: 16),
                    BudgetComparisonCard(
                      key: ValueKey(_payload.weekStart),
                      forWeekStart: _payload.weekStart,
                    ),
                    const SizedBox(height: 16),
                    _buildContributionSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _finishAndExit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text("Contribute & finish"),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionSection() {
    final goals = _payload.goals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Contribute to goals",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (goals.isEmpty)
              const Text("No active goals yet. Create one to start saving!")
            else
              ...goals.map(_buildGoalRow),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(GoalModel goal) {
    final id = goal.id;
    final selectable = id != null;
    final selected = selectable && _selectedGoalIds.contains(id);
    final controller = selectable ? _amountControllers[id] : null;
    final remaining = goal.amount > 0 ? (goal.amount - goal.savedAmount).clamp(0, double.infinity) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: selectable
                    ? (value) {
                        setState(() {
                          if (value == true) {
                            _selectedGoalIds.add(id!);
                          } else {
                            _selectedGoalIds.remove(id);
                          }
                        });
                      }
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      goal.amount > 0
                          ? "\$${goal.savedAmount.toStringAsFixed(0)} / \$${goal.amount.toStringAsFixed(0)} saved"
                          : "\$${goal.savedAmount.toStringAsFixed(0)} saved",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (remaining != null && remaining > 0)
                      Text(
                        "\$${remaining.toStringAsFixed(0)} remaining",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: controller,
                  enabled: selectable,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: "\$",
                    labelText: "Amount",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasContributionRequest =>
      _selectedGoalIds.any((id) => _amountForGoal(id) > 0);

  Future<bool> _applySelectedContributionsIfNeeded() async {
    if (!_hasContributionRequest) {
      return true;
    }
    final scaffold = ScaffoldMessenger.of(context);
    setState(() {
      _submitting = true;
    });
    try {
      bool anyApplied = false;
      for (final goal in _payload.goals) {
        final id = goal.id;
        if (id == null || !_selectedGoalIds.contains(id)) continue;
        final amount = _amountForGoal(id);
        if (amount <= 0) continue;
        final applied = await GoalRepository.addManualContribution(goal, amount);
        if (applied > 0) {
          await _recordContributionTransaction(goal, applied);
          anyApplied = true;
          scaffold.showSnackBar(
            SnackBar(content: Text("Added \$${applied.toStringAsFixed(2)} to ${goal.name}")),
          );
        }
      }
      if (!anyApplied) {
        scaffold.showSnackBar(
          const SnackBar(
            content: Text(
                "Enter an amount for selected goals or deselect them to finish."),
          ),
        );
        return false;
      }
      await _refreshPayload();
      return true;
    } catch (err) {
      scaffold.showSnackBar(
        SnackBar(content: Text("Failed to contribute: $err")),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _finishAndExit() async {
    if (_submitting) return;
    final contributionsOk = await _applySelectedContributionsIfNeeded();
    if (!contributionsOk || !mounted) return;
    
    // Save the current report to persist "left to spend" for streak tracking.
    // This ensures the streak counter gets updated whether or not contributions were made.
    await WeeklyReportRepository.upsert(_payload.report);
    
    final finishCallback = widget.onFinish;
    Navigator.of(context).pop();
    if (finishCallback != null) {
      await finishCallback();
    }
  }

  Future<void> _recordContributionTransaction(
      GoalModel goal, double amount) async {
    final today = DateTime.now();
    final dateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    await TransactionRepository.insertManual(
      TransactionModel(
        amount: -amount,
        description: "Goal contribution: ${goal.name}",
        date: dateStr,
        type: 'expense',
        categoryName: 'Goal contribution',
      ),
    );
  }

  Future<void> _refreshPayload() async {
    final refreshedReport = await InsightsService.generateReportForWeek(
      _payload.weekStart,
      persist: true,
      usePreviousWeekIncome: false,
    );
    final summary = refreshedReport.overviewSummary;
    if (!mounted || summary == null) return;
    final refreshedGoals = (await GoalRepository.getAll())
        .where((goal) => !goal.isComplete)
        .toList();
    setState(() {
      _payload = WeeklyOverviewPayload(
        weekStart: _payload.weekStart,
        report: refreshedReport,
        summary: summary,
        goals: refreshedGoals,
      );
      _selectedGoalIds.clear();
    });
    _seedControllers();
    _autoSelectGoals(emitSetState: true);
  }

  String _formatRange(DateTime start, DateTime end) {
    String fmt(DateTime d) =>
        "${d.day}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}";
    return "${fmt(start)} → ${fmt(end)}";
  }

  String _encouragementMessage(double left, double total) {
    if (total <= 0) {
      return "Let’s set up your budget and make a plan 🚀";
    }
    if (left < 0) {
      return "Slightly over — no stress. Fresh week, fresh start.";
    }
    final ratio = left / total;
    if (ratio >= 0.75) return "Crushing it — plenty left this week 💪";
    if (ratio >= 0.50) return "You're on track! 🌟";
    if (ratio >= 0.25) return "You're doing fine — keep an eye on it 👀";
    if (ratio >= 0.10) return "Tight but doable — small choices win 💡";
    return "Almost tapped out — press pause on extras if you can ⏸️";
  }
}

class _OverviewStats extends StatelessWidget {
  final double weeklyBudget;
  final double leftToSpend;
  final String encouragement;

  const _OverviewStats({
    required this.weeklyBudget,
    required this.leftToSpend,
    required this.encouragement,
  });

  @override
  Widget build(BuildContext context) {
    final leftPositive = leftToSpend >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          encouragement,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: "Weekly budget",
                value: _currency(weeklyBudget),
                accent: Colors.blueGrey.shade50,
                valueColor: Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: "Left to spend",
                value: _currency(leftToSpend),
                accent: leftPositive ? Colors.teal.shade50 : Colors.red.shade50,
                valueColor: leftPositive ? Colors.teal : Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _currency(double value) =>
      "\$${value.toStringAsFixed(value.abs() >= 100 ? 0 : 2)}";
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
