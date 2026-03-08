import 'package:flutter/material.dart';

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/budget_buffer_refresh.dart';
import 'package:bfm_app/services/budget_buffer_store.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
import 'package:bfm_app/widgets/budget_buffer_card.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';
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
  
  /// Left to spend using dashboard formula: income - budgeted - budgetOverspend - nonBudgetSpend
  /// This accounts for budget allocations, not just raw income minus spending.
  double get _baseLeftToSpend {
    final report = _payload.report;
    // Use the overviewSummary's leftToSpend which uses the dashboard formula
    if (report.overviewSummary != null) {
      return report.overviewSummary!.leftToSpend;
    }
    // Fallback: calculate using dashboard formula if no summary
    // Calculate budget spent from categories with budgets
    double budgetSpent = 0;
    for (final cat in report.categories) {
      if (cat.budget > 0) {
        budgetSpent += cat.spent;
      }
    }
    final budgetOverspend = (budgetSpent - report.totalBudget).clamp(0.0, double.infinity);
    final nonBudgetSpend = (report.totalSpent - budgetSpent).clamp(0.0, double.infinity);
    return report.totalIncome - report.totalBudget - budgetOverspend - nonBudgetSpend;
  }
  
  /// App savings state - tracks money saved via the app
  double _appSavingsTotal = 0.0;
  bool _addToAppSavings = false;

  /// Budget buffer state — per-budget balances and contributions
  Map<String, double> _bufferBalances = {};
  Map<String, double> _bufferContributions = {};
  Map<String, String> _bufferEmojis = {};
  
  /// The deficit amount when left to spend is negative.
  double get _leftToSpendDeficit =>
      _baseLeftToSpend < 0 ? _baseLeftToSpend.abs() : 0.0;

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
    _loadAppSavings();
    _loadBudgetBuffer();
  }
  
  Future<void> _loadAppSavings() async {
    final total = await AppSavingsStore.getTotal();
    if (!mounted) return;
    setState(() {
      _appSavingsTotal = total;
      if (_baseLeftToSpend > 0) {
        _addToAppSavings = true;
      }
      // Auto-select savings goals now that we know the total
      _autoSelectGoals(emitSetState: false);
    });
  }
  
  Future<void> _loadBudgetBuffer() async {
    final balances = await BudgetBufferStore.getAll();
    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();

    // Per-budget contributions from this week's report
    final contribs = <String, double>{};
    final emojis = <String, String>{};
    for (final cat in _payload.report.categories) {
      if (cat.budget > 0) {
        contribs[cat.label] = cat.budget - cat.spent;
        emojis[cat.label] = emojiHelper.emojiForName(cat.label);
      }
    }
    // Also ensure stored buffers have emojis
    for (final label in balances.keys) {
      emojis.putIfAbsent(label, () => emojiHelper.emojiForName(label));
    }

    if (!mounted) return;
    setState(() {
      _bufferBalances = balances;
      _bufferContributions = contribs;
      _bufferEmojis = emojis;
    });
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

  /// Auto-selects savings goals if they all fit in the available budget.
  /// Only called when no recovery goal exists.
  void _autoSelectGoals({bool emitSetState = true}) {
    void applySelection() {
      _selectedGoalIds.clear();
      final ids = _payload.goals.map((g) => g.id).whereType<int>().toList();
      if (ids.isEmpty) return;
      
      final total = ids.fold<double>(0, (sum, id) => sum + _amountForGoal(id));
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _payload.summary;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
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
                    _OverviewStats(leftToSpend: _visibleLeftToSpend),
                    const SizedBox(height: 16),
                    CombinedChartCard(
                      report: _payload.report,
                      showStats: false,
                    ),
                    const SizedBox(height: 16),
                    WeeklyBudgetBreakdownCard(
                      key: ValueKey(_payload.weekStart),
                      forWeekStart: _payload.weekStart,
                    ),
                    const SizedBox(height: 16),
                    BudgetBufferCard(entries: _buildBufferEntries()),
                    const SizedBox(height: 16),
                    _buildAppSavingsSection(),
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

  /// Total amount drawn from Buxly Buffer to cover budget buffer deficits.
  double get _bufferRecoveryAmount {
    return _buildBufferEntries().fold<double>(
      0, (sum, e) => sum + (e.savingsDrawn ?? 0),
    );
  }

  /// App savings after accounting for buffer deficits and left-to-spend deficit.
  double get _adjustedAppSavings {
    return _appSavingsTotal - _bufferRecoveryAmount - _leftToSpendDeficit;
  }
  
  /// Builds the Buxly Buffer card showing current balance, deductions, and
  /// (when under budget) an option to add leftover to savings.
  Widget _buildAppSavingsSection() {
    final isOverBudget = _baseLeftToSpend < 0;
    final leftover = (_baseLeftToSpend - _selectedContributionTotal)
        .clamp(0.0, double.infinity);
    final bufferRecovery = _bufferRecoveryAmount;
    final adjusted = _adjustedAppSavings;
    final hasDeductions = bufferRecovery > 0 || _leftToSpendDeficit > 0;
    final cardColor =
        hasDeductions ? Colors.orange.shade50 : Colors.teal.shade50;
    final accentColor =
        hasDeductions ? Colors.orange.shade700 : Colors.teal.shade700;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.savings, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Buxly Buffer",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: hasDeductions
                        ? Colors.orange.shade800
                        : Colors.teal.shade800,
                  ),
                ),
                const Spacer(),
                HelpIconTooltip(
                  title: 'Buxly Buffer',
                  message:
                      'Money you save by staying under budget each week.\n\n'
                      'If you go over budget or a budget buffer goes negative, '
                      'the Buxly Buffer absorbs the deficit.',
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Breakdown container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Current balance (before any deductions)
                  _savingsRow(
                    "Current balance",
                    _appSavingsTotal,
                    bold: false,
                  ),

                  // Buffer recovery deduction
                  if (bufferRecovery > 0) ...[
                    const SizedBox(height: 6),
                    _savingsRow(
                      "Buffer recovery",
                      -bufferRecovery,
                      color: Colors.orange.shade700,
                    ),
                  ],

                  // Over-budget deduction
                  if (_leftToSpendDeficit > 0) ...[
                    const SizedBox(height: 6),
                    _savingsRow(
                      "Over budget",
                      -_leftToSpendDeficit,
                      color: Colors.red.shade600,
                    ),
                  ],

                  // Divider + total when there are deductions
                  if (hasDeductions) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    _savingsRow(
                      "Savings after this week",
                      adjusted,
                      bold: true,
                      color: adjusted >= 0
                          ? Colors.teal.shade700
                          : Colors.red.shade600,
                    ),
                  ],
                ],
              ),
            ),

            // Add-to-savings checkbox (only when under budget)
            if (!isOverBudget && leftover > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _addToAppSavings
                        ? Colors.teal.shade400
                        : Colors.teal.shade200,
                    width: _addToAppSavings ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _addToAppSavings,
                      activeColor: Colors.teal.shade600,
                      onChanged: (v) =>
                          setState(() => _addToAppSavings = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _addToAppSavings = !_addToAppSavings),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Save \$${leftover.toStringAsFixed(0)} to Buxly Buffer",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "New total: \$${(adjusted + (_addToAppSavings ? leftover : 0)).toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper to render a label + dollar amount row in the savings breakdown.
  Widget _savingsRow(
    String label,
    double amount, {
    bool bold = false,
    Color? color,
  }) {
    final isNegative = amount < 0;
    final displayColor = color ??
        (isNegative ? Colors.red.shade600 : Colors.black87);
    final formatted = isNegative
        ? "−\$${amount.abs().toStringAsFixed(0)}"
        : "\$${amount.toStringAsFixed(0)}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          formatted,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: displayColor,
          ),
        ),
      ],
    );
  }

  Future<void> _applySelectedContributionsIfNeeded() async {
    final scaffold = ScaffoldMessenger.of(context);
    for (final goal in _payload.goals) {
      final id = goal.id;
      if (id == null || !_selectedGoalIds.contains(id)) continue;
      final amount = _amountForGoal(id);
      if (amount <= 0) continue;
      final applied = await GoalRepository.addManualContribution(goal, amount);
      if (applied > 0) {
        await _recordContributionTransaction(goal, applied);
        scaffold.showSnackBar(
          SnackBar(content: Text("Added \$${applied.toStringAsFixed(2)} to ${goal.name}")),
        );
      }
    }
  }

  List<BufferEntry> _buildBufferEntries() {
    final allLabels = <String>{
      ..._bufferBalances.keys,
      ..._bufferContributions.keys,
    };
    final entries = <BufferEntry>[];
    for (final label in allLabels) {
      final existing = _bufferBalances[label] ?? 0.0;
      final contrib = _bufferContributions[label] ?? 0.0;
      final rawBalance = existing + contrib;
      final projected = rawBalance.clamp(0.0, double.infinity);
      // If the balance went negative, the deficit is drawn from app savings
      final savingsDrawn = rawBalance < 0 ? rawBalance.abs() : 0.0;
      if (projected <= 0 && contrib == 0) continue;
      entries.add(BufferEntry(
        label: label,
        emoji: _bufferEmojis[label] ?? '📦',
        buffered: projected,
        contribution: contrib,
        savingsDrawn: savingsDrawn > 0 ? savingsDrawn : null,
      ));
    }
    entries.sort((a, b) => b.buffered.compareTo(a.buffered));
    return entries;
  }

  Future<void> _finishAndExit() async {
    if (_submitting) return;
    
    setState(() {
      _submitting = true;
    });
    
    final scaffold = ScaffoldMessenger.of(context);
    
    try {
      // Apply savings goal contributions first
      await _applySelectedContributionsIfNeeded();
      if (!mounted) return;
      
      // Handle app savings: add leftover or reduce by deficit
      if (_addToAppSavings && _baseLeftToSpend > 0) {
        final leftover = (_baseLeftToSpend - _selectedContributionTotal).clamp(0.0, double.infinity);
        if (leftover > 0) {
          final newTotal = await AppSavingsStore.add(leftover);
          scaffold.showSnackBar(
            SnackBar(content: Text("Added \$${leftover.toStringAsFixed(0)} to Buxly Buffer (total: \$${newTotal.toStringAsFixed(0)})")),
          );
        }
      }

      // Withdraw buffer deficits (always apply when user confirms)
      final bufferRecovery = _bufferRecoveryAmount;
      if (bufferRecovery > 0) {
        await AppSavingsStore.withdraw(bufferRecovery);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
                "−\$${bufferRecovery.toStringAsFixed(0)} from Buxly Buffer (buffer recovery)"),
          ),
        );
      }

      // If over budget, reduce Buxly Buffer by the deficit
      if (_leftToSpendDeficit > 0) {
        await AppSavingsStore.withdraw(_leftToSpendDeficit);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
                "−\$${_leftToSpendDeficit.toStringAsFixed(0)} from Buxly Buffer (over budget)"),
          ),
        );
      }

      // Process per-budget buffer contributions (update buffer balances, no withdrawal - we already did it)
      if (_bufferContributions.isNotEmpty) {
        final weekStartStr =
            "${_payload.weekStart.year.toString().padLeft(4, '0')}-${_payload.weekStart.month.toString().padLeft(2, '0')}-${_payload.weekStart.day.toString().padLeft(2, '0')}";
        await BudgetBufferStore.applyWeeklyContributions(
          contributions: _bufferContributions,
          weekStart: weekStartStr,
          onNegative: null, // Already withdrew above
        );
      }
      notifyBudgetBufferUpdated();

      // Save the current report to persist "left to spend" for streak tracking.
      await WeeklyReportRepository.upsert(_payload.report);
      
      final finishCallback = widget.onFinish;
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (finishCallback != null) {
        await finishCallback();
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
  
  Future<void> _recordContributionTransaction(
      GoalModel goal, double amount) async {
    // Date the transaction to the end of the week being reviewed
    final weekEnd = _payload.weekEnd;
    final dateStr =
        "${weekEnd.year.toString().padLeft(4, '0')}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}";
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
      usePreviousWeekIncome: true,
    );
    final summary = refreshedReport.overviewSummary;
    if (!mounted || summary == null) return;
    final refreshedGoals = (await GoalRepository.getSavingsGoals())
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

}

class _OverviewStats extends StatelessWidget {
  final double leftToSpend;

  const _OverviewStats({
    required this.leftToSpend,
  });

  @override
  Widget build(BuildContext context) {
    final leftPositive = leftToSpend >= 0;
    return _SummaryCard(
      label: "Left to spend",
      value: _currency(leftToSpend),
      accent: leftPositive ? Colors.teal.shade50 : Colors.red.shade50,
      valueColor: leftPositive ? Colors.teal : Colors.redAccent,
      helpTitle: "Left to Spend",
      helpMessage: "Your remaining discretionary budget after spending.\n\n"
          "Calculation: Weekly Budget − Budget Overspend − Non-budget Spending\n\n"
          "Where:\n"
          "• Weekly Budget = Income − Total Budgeted\n"
          "• Budget Overspend = max(0, budget spent − budget limits)\n"
          "• Non-budget Spending = spending outside budget categories\n\n"
          "This shows money available for non-budget spending.",
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
  final String? helpTitle;
  final String? helpMessage;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
    this.helpTitle,
    this.helpMessage,
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
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              if (helpMessage != null)
                HelpIconTooltip(
                  title: helpTitle ?? label,
                  message: helpMessage!,
                  size: 14,
                ),
            ],
          ),
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
