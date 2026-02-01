import 'package:flutter/material.dart';

import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/weekly_report_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/insights_service.dart';
import 'package:bfm_app/services/weekly_overview_service.dart';
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
  
  /// Recovery goals that the user can contribute to.
  List<GoalModel> _recoveryGoals = [];
  final Map<int, TextEditingController> _recoveryAmountControllers = {};
  final Set<int> _selectedRecoveryGoalIds = {};
  
  /// Recovery goal creation/update state (inline checkbox approach)
  bool _createOrAddToRecovery = false;
  int _recoveryWeeks = 4;
  
  /// App savings state - tracks money saved via the app
  double _appSavingsTotal = 0.0;
  bool _addToAppSavings = false;
  bool _useAppSavingsForRecovery = false;
  double _appSavingsToAdd = 0.0;
  
  /// New deficit from this week (base overspend + any savings contributions)
  double get _totalDeficit {
    final baseDeficit = _baseLeftToSpend < 0 ? _baseLeftToSpend.abs() : 0.0;
    // Add any savings goal contributions when already over budget
    final savingsContributions = _selectedGoalIds.fold<double>(
      0, (sum, id) => sum + _amountForGoal(id)
    );
    return baseDeficit + savingsContributions;
  }
  
  /// Existing recovery goal's remaining amount (if any)
  double get _existingRecoveryRemaining {
    if (_recoveryGoals.isEmpty) return 0.0;
    final goal = _recoveryGoals.first;
    return (goal.amount - goal.savedAmount).clamp(0.0, double.infinity);
  }
  
  /// Total recovery amount: existing remaining + new deficit
  double get _totalRecoveryAmount => _existingRecoveryRemaining + _totalDeficit;
  
  /// Weekly payment based on total recovery amount and selected weeks
  double get _recoveryWeeklyPayment => 
      _recoveryWeeks > 0 ? _totalRecoveryAmount / _recoveryWeeks : 0.0;
  
  /// Amount of deficit that can be covered by app savings
  double get _savingsCoverageAmount {
    if (!_useAppSavingsForRecovery || _appSavingsTotal <= 0) return 0.0;
    return _totalDeficit.clamp(0.0, _appSavingsTotal);
  }
  
  /// Remaining deficit after using app savings
  double get _deficitAfterSavings => (_totalDeficit - _savingsCoverageAmount).clamp(0.0, double.infinity);
  
  /// Whether the deficit is fully covered by savings
  bool get _deficitFullyCoveredBySavings => _useAppSavingsForRecovery && _savingsCoverageAmount >= _totalDeficit;

  double get _selectedContributionTotal {
    double total = 0;
    for (final id in _selectedGoalIds) {
      total += _amountForGoal(id);
    }
    // Include recovery goal contributions
    for (final id in _selectedRecoveryGoalIds) {
      total += _amountForRecoveryGoal(id);
    }
    return total;
  }
  
  double _amountForRecoveryGoal(int id) {
    final controller = _recoveryAmountControllers[id];
    final text = controller?.text ?? '';
    final parsed = double.tryParse(text.replaceAll(',', ''));
    if (parsed != null && parsed > 0) return parsed;
    final goal = _recoveryGoals.firstWhere(
      (g) => g.id == id,
      orElse: () => const GoalModel(id: null, name: '', amount: 0, weeklyContribution: 0),
    );
    if (goal.id == null) return 0;
    return goal.weeklyContribution > 0 ? goal.weeklyContribution : 10.0;
  }

  double get _visibleLeftToSpend => _baseLeftToSpend - _selectedContributionTotal;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
    _seedControllers();
    // Don't auto-select savings goals here - wait for recovery to load first
    // so recovery takes priority
    _loadRecoveryGoals();
    _loadAppSavings();
  }
  
  Future<void> _loadAppSavings() async {
    final total = await AppSavingsStore.getTotal();
    if (!mounted) return;
    setState(() {
      _appSavingsTotal = total;
      // Auto-select savings checkbox if user has money left
      if (_baseLeftToSpend > 0) {
        _addToAppSavings = true;
        _appSavingsToAdd = _baseLeftToSpend;
      }
      // Auto-select recovery checkbox if over budget
      if (_baseLeftToSpend < 0) {
        _createOrAddToRecovery = true;
        // If we have app savings and a deficit, auto-select to use them
        if (_appSavingsTotal > 0) {
          _useAppSavingsForRecovery = true;
        }
      }
    });
  }
  
  Future<void> _loadRecoveryGoals() async {
    final recoveryGoals = await GoalRepository.getActiveRecoveryGoals();
    if (!mounted) return;
    setState(() {
      _recoveryGoals = recoveryGoals;
      _seedRecoveryControllers();
      
      if (recoveryGoals.isNotEmpty && _baseLeftToSpend > 0) {
        final existingGoal = recoveryGoals.first;
        _recoveryWeeks = existingGoal.recoveryWeeks ?? 4;
        final remaining = (existingGoal.amount - existingGoal.savedAmount).clamp(0.0, double.infinity);
        
        if (remaining > 0 && existingGoal.id != null) {
          // Use smart auto-selection: recovery first, then savings, then leftover to recovery
          _autoSelectWithRecoveryPriority(existingGoal);
        } else {
          // Recovery is complete, just select savings goals
          _autoSelectGoals(emitSetState: false);
        }
      } else if (recoveryGoals.isEmpty) {
        // No recovery goal exists, just select savings goals
        _autoSelectGoals(emitSetState: false);
      }
      // If leftToSpend <= 0 with recovery, don't auto-select anything
    });
  }
  
  /// Smart auto-selection that prioritizes recovery, then savings, then leftover back to recovery.
  /// 
  /// Logic:
  /// 1. If can't afford full weekly contribution → contribute all leftToSpend to recovery
  /// 2. If can afford weekly → pay weekly, then savings goals, then leftover goes to recovery
  void _autoSelectWithRecoveryPriority(GoalModel recoveryGoal) {
    final weeklyContribution = recoveryGoal.weeklyContribution;
    final remaining = (recoveryGoal.amount - recoveryGoal.savedAmount).clamp(0.0, double.infinity);
    final goalId = recoveryGoal.id!;
    
    // Step 1: Calculate initial recovery contribution
    // If can't afford full weekly, contribute whatever we have
    final initialRecovery = _baseLeftToSpend.clamp(0.0, weeklyContribution).clamp(0.0, remaining);
    
    // Step 2: Calculate what's available for savings goals
    final availableForSavings = _baseLeftToSpend - initialRecovery;
    
    // Step 3: Select savings goals if they ALL fit in remaining budget
    final savingsIds = _payload.goals.map((g) => g.id).whereType<int>().toList();
    final savingsTotal = savingsIds.fold<double>(0, (sum, id) => sum + _amountForGoal(id));
    
    double selectedSavingsTotal = 0;
    _selectedGoalIds.clear();
    if (savingsTotal <= availableForSavings + 0.01) {
      _selectedGoalIds.addAll(savingsIds);
      selectedSavingsTotal = savingsTotal;
    }
    
    // Step 4: Any leftover after savings goes back to recovery as bonus
    final leftoverAfterSavings = availableForSavings - selectedSavingsTotal;
    final totalRecoveryContrib = (initialRecovery + leftoverAfterSavings).clamp(0.0, remaining);
    
    // Step 5: Update the recovery controller with calculated amount
    final controller = _recoveryAmountControllers[goalId];
    if (controller != null) {
      // Temporarily remove listener to avoid side effects during setup
      controller.removeListener(_handleContributionAmountChanged);
      final decimals = totalRecoveryContrib % 1 == 0 ? 0 : 2;
      controller.text = totalRecoveryContrib.toStringAsFixed(decimals);
      controller.addListener(_handleContributionAmountChanged);
    }
    
    // Step 6: Auto-select recovery contribution
    _selectedRecoveryGoalIds.clear();
    _selectedRecoveryGoalIds.add(goalId);
  }
  
  void _seedRecoveryControllers() {
    _disposeRecoveryControllers();
    for (final goal in _recoveryGoals) {
      final id = goal.id;
      if (id == null) continue;
      final initial = goal.weeklyContribution > 0 ? goal.weeklyContribution : 10.0;
      final decimals = initial % 1 == 0 ? 0 : 2;
      final controller = TextEditingController(text: initial.toStringAsFixed(decimals));
      controller.addListener(_handleContributionAmountChanged);
      _recoveryAmountControllers[id] = controller;
    }
  }
  
  void _disposeRecoveryControllers() {
    for (final controller in _recoveryAmountControllers.values) {
      controller.removeListener(_handleContributionAmountChanged);
      controller.dispose();
    }
    _recoveryAmountControllers.clear();
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
    if (mounted) {
      setState(() {
        // Auto-select recovery checkbox if contributing to savings while over budget
        if (_totalDeficit > 0 && !_createOrAddToRecovery) {
          _createOrAddToRecovery = true;
        }
        // Let user see the impact of their changes via the "left to spend" display
        // Don't auto-deselect - they can manually adjust if needed
      });
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _disposeRecoveryControllers();
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
                    _OverviewStats(
                      weeklyBudget: summary.weeklyBudget,
                      leftToSpend: _visibleLeftToSpend,
                    ),
                    const SizedBox(height: 16),
                    CombinedChartCard(
                      report: _payload.report,
                      showStats: false,
                    ),
                    const SizedBox(height: 16),
                    BudgetComparisonCard(
                      key: ValueKey(_payload.weekStart),
                      forWeekStart: _payload.weekStart,
                    ),
                    if (_shouldShowAppSavingsSection) ...[
                      const SizedBox(height: 16),
                      _buildAppSavingsSection(),
                    ],
                    if (_shouldShowRecoverySection) ...[
                      const SizedBox(height: 16),
                      _buildRecoverySection(),
                    ],
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
      _selectedGoalIds.any((id) => _amountForGoal(id) > 0) ||
      _selectedRecoveryGoalIds.any((id) => _amountForRecoveryGoal(id) > 0);
  
  /// Whether the app savings section should be visible.
  /// Shows when user has money left to spend (positive leftToSpend).
  bool get _shouldShowAppSavingsSection => _baseLeftToSpend > 0;
  
  /// Builds the app savings card for adding leftover money to savings.
  Widget _buildAppSavingsSection() {
    final leftover = _baseLeftToSpend - _selectedContributionTotal;
    final effectiveLeftover = leftover.clamp(0.0, double.infinity);
    
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: Colors.teal.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  "App Savings",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.teal.shade800,
                  ),
                ),
                const Spacer(),
                HelpIconTooltip(
                  title: 'App Savings',
                  message: 'Money you save by staying under budget each week.\n\n'
                      'This tracks your cumulative savings achieved through the app. '
                      'If you ever go over budget, these savings can automatically cover the deficit.',
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Current savings total
            if (_appSavingsTotal > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Current savings",
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      "\$${_appSavingsTotal.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Add to savings option
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _addToAppSavings ? Colors.teal.shade400 : Colors.teal.shade200,
                  width: _addToAppSavings ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _addToAppSavings,
                    activeColor: Colors.teal.shade600,
                    onChanged: (value) {
                      setState(() {
                        _addToAppSavings = value ?? false;
                        if (_addToAppSavings) {
                          _appSavingsToAdd = effectiveLeftover;
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _addToAppSavings = !_addToAppSavings;
                          if (_addToAppSavings) {
                            _appSavingsToAdd = effectiveLeftover;
                          }
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Save \$${effectiveLeftover.toStringAsFixed(0)} to app savings",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "New total: \$${(_appSavingsTotal + effectiveLeftover).toStringAsFixed(0)}",
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
        ),
      ),
    );
  }
  
  /// Whether the recovery section should be visible.
  bool get _shouldShowRecoverySection =>
      _baseLeftToSpend < 0 || _recoveryGoals.isNotEmpty;
  
  Widget _buildRecoverySection() {
    final isOverBudget = _baseLeftToSpend < 0;
    
    // Don't show recovery section if user has money left AND no existing recovery goals
    // Only show "create recovery" option when actually over budget (negative left to spend)
    if (!isOverBudget && _recoveryGoals.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final hasExistingRecovery = _recoveryGoals.isNotEmpty;
    final existingGoal = hasExistingRecovery ? _recoveryGoals.first : null;
    
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_down, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  hasExistingRecovery ? "Recovery Goal" : "Budget Recovery",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Show existing recovery goal progress if exists
            if (hasExistingRecovery && existingGoal != null) ...[
              _buildExistingRecoveryInfo(existingGoal),
              const SizedBox(height: 12),
            ],
            
            // Show create/add to recovery option if actually over budget
            if (isOverBudget) ...[
              _buildRecoveryCheckboxSection(hasExistingRecovery, existingGoal),
            ],
            
            // Show contribute option for existing recovery if not over budget
            if (!isOverBudget && hasExistingRecovery && existingGoal != null) ...[
              _buildRecoveryContributeSection(existingGoal),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Shows current recovery goal progress info.
  Widget _buildExistingRecoveryInfo(GoalModel goal) {
    final remaining = (goal.amount - goal.savedAmount).clamp(0.0, double.infinity);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "\$${goal.savedAmount.toStringAsFixed(0)} paid back",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                "\$${remaining.toStringAsFixed(0)} remaining",
                style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progressFraction,
            minHeight: 6,
            backgroundColor: Colors.orange.shade100,
            color: Colors.orange.shade600,
          ),
        ],
      ),
    );
  }
  
  /// Checkbox section for creating new or adding to existing recovery goal.
  Widget _buildRecoveryCheckboxSection(bool hasExisting, GoalModel? existingGoal) {
    // Show savings coverage option first if user has app savings
    final hasSavings = _appSavingsTotal > 0;
    final canCoverFully = _savingsCoverageAmount >= _totalDeficit;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Option to use app savings if available
        if (hasSavings) ...[
          _buildSavingsCoverageOption(canCoverFully),
          if (!_deficitFullyCoveredBySavings) ...[
            const SizedBox(height: 12),
          ],
        ],
        
        // Only show recovery goal option if deficit isn't fully covered by savings
        if (!_deficitFullyCoveredBySavings) ...[
          _buildRecoveryGoalOption(hasExisting, existingGoal),
        ],
      ],
    );
  }
  
  /// Builds the option to use app savings to cover the deficit.
  Widget _buildSavingsCoverageOption(bool canCoverFully) {
    final coverageText = canCoverFully
        ? "Use \$${_totalDeficit.toStringAsFixed(0)} from app savings"
        : "Use \$${_appSavingsTotal.toStringAsFixed(0)} from app savings";
    final subtitleText = canCoverFully
        ? "Fully covers this week's deficit!"
        : "Covers \$${_savingsCoverageAmount.toStringAsFixed(0)} of \$${_totalDeficit.toStringAsFixed(0)} deficit";
    final remainingAfter = _appSavingsTotal - _savingsCoverageAmount;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _useAppSavingsForRecovery ? Colors.teal.shade400 : Colors.teal.shade200,
          width: _useAppSavingsForRecovery ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _useAppSavingsForRecovery,
                activeColor: Colors.teal.shade600,
                onChanged: (value) {
                  setState(() {
                    _useAppSavingsForRecovery = value ?? false;
                    // If fully covered, disable recovery goal creation
                    if (_useAppSavingsForRecovery && canCoverFully) {
                      _createOrAddToRecovery = false;
                    }
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _useAppSavingsForRecovery = !_useAppSavingsForRecovery;
                      if (_useAppSavingsForRecovery && canCoverFully) {
                        _createOrAddToRecovery = false;
                      }
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              coverageText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 12,
                          color: canCoverFully ? Colors.teal.shade700 : Colors.teal.shade600,
                          fontWeight: canCoverFully ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (_useAppSavingsForRecovery)
                        Text(
                          "Savings after: \$${remainingAfter.toStringAsFixed(0)}",
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
        ],
      ),
    );
  }
  
  /// Builds the recovery goal creation/update option.
  Widget _buildRecoveryGoalOption(bool hasExisting, GoalModel? existingGoal) {
    // Calculate amounts considering savings usage
    final effectiveDeficit = _deficitAfterSavings;
    final String actionText;
    final String? subtitleText;
    
    if (hasExisting) {
      final existingRemaining = _existingRecoveryRemaining;
      final newTotal = existingRemaining + effectiveDeficit;
      actionText = "Update recovery goal to \$${newTotal.toStringAsFixed(0)}";
      if (_useAppSavingsForRecovery && _savingsCoverageAmount > 0) {
        subtitleText = "\$${existingRemaining.toStringAsFixed(0)} existing + \$${effectiveDeficit.toStringAsFixed(0)} remaining";
      } else {
        subtitleText = "\$${existingRemaining.toStringAsFixed(0)} existing + \$${effectiveDeficit.toStringAsFixed(0)} new";
      }
    } else {
      actionText = "Create recovery goal for \$${effectiveDeficit.toStringAsFixed(0)}";
      if (_useAppSavingsForRecovery && _savingsCoverageAmount > 0) {
        subtitleText = "After using \$${_savingsCoverageAmount.toStringAsFixed(0)} from savings";
      } else {
        subtitleText = null;
      }
    }
    
    final effectiveRecoveryAmount = _existingRecoveryRemaining + effectiveDeficit;
    final effectiveWeeklyPayment = _recoveryWeeks > 0 ? effectiveRecoveryAmount / _recoveryWeeks : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _createOrAddToRecovery ? Colors.orange.shade400 : Colors.orange.shade200,
          width: _createOrAddToRecovery ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox row
          Row(
            children: [
              Checkbox(
                value: _createOrAddToRecovery,
                activeColor: Colors.orange.shade600,
                onChanged: (value) {
                  setState(() {
                    _createOrAddToRecovery = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _createOrAddToRecovery = !_createOrAddToRecovery;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitleText != null)
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Weeks selector (only show if checkbox is selected)
          if (_createOrAddToRecovery) ...[
            const SizedBox(height: 12),
            // Row 1: Weeks selector
            Row(
              children: [
                const Text(
                  "Pay back over:",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _recoveryWeeks > 1
                      ? () => setState(() => _recoveryWeeks--)
                      : null,
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$_recoveryWeeks wks",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _recoveryWeeks < 24
                      ? () => setState(() => _recoveryWeeks++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Weekly payment amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "\$${effectiveWeeklyPayment.toStringAsFixed(2)} per week",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Contribute section for existing recovery goal when not currently over budget.
  Widget _buildRecoveryContributeSection(GoalModel goal) {
    final id = goal.id;
    final remaining = (goal.amount - goal.savedAmount).clamp(0.0, double.infinity);
    final weeklyContribution = goal.weeklyContribution;
    final isSelected = id != null && _selectedRecoveryGoalIds.contains(id);
    
    // Get the actual calculated amount from the controller
    final actualAmount = id != null ? _amountForRecoveryGoal(id) : 0.0;
    final remainingAfterContrib = (remaining - actualAmount).clamp(0.0, double.infinity);
    
    if (remaining <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Text(
              "Fully paid back!",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    // Determine the label based on amount vs weekly contribution
    String paymentLabel;
    if (actualAmount >= weeklyContribution) {
      if (actualAmount > weeklyContribution) {
        final leftover = actualAmount - weeklyContribution;
        paymentLabel = "Pay \$${actualAmount.toStringAsFixed(2)} (\$${weeklyContribution.toStringAsFixed(0)} weekly + \$${leftover.toStringAsFixed(0)} left over)";
      } else {
        paymentLabel = "Pay \$${actualAmount.toStringAsFixed(2)} this week";
      }
    } else {
      paymentLabel = "Pay \$${actualAmount.toStringAsFixed(2)} (partial payment)";
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange.shade400 : Colors.orange.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: Colors.orange.shade600,
                onChanged: id != null
                    ? (value) {
                        setState(() {
                          if (value == true) {
                            _selectedRecoveryGoalIds.add(id);
                          } else {
                            _selectedRecoveryGoalIds.remove(id);
                          }
                        });
                      }
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "\$${remainingAfterContrib.toStringAsFixed(0)} remaining after this",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applySelectedContributionsIfNeeded() async {
    final scaffold = ScaffoldMessenger.of(context);
    
    // Handle regular savings goal contributions
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
    
    // Handle recovery goal contributions (when not in deficit - just paying weekly amount)
    for (final goal in _recoveryGoals) {
      final id = goal.id;
      if (id == null || !_selectedRecoveryGoalIds.contains(id)) continue;
      final amount = _amountForRecoveryGoal(id);
      if (amount <= 0) continue;
      final applied = await GoalRepository.addManualContribution(goal, amount);
      if (applied > 0) {
        await _recordRecoveryContributionTransaction(goal, applied);
        scaffold.showSnackBar(
          SnackBar(content: Text("Paid back \$${applied.toStringAsFixed(2)} on recovery goal")),
        );
      }
    }
  }
  
  Future<void> _recordRecoveryContributionTransaction(
      GoalModel goal, double amount) async {
    // Date the transaction to the end of the week being reviewed
    final weekEnd = _payload.weekEnd;
    final dateStr =
        "${weekEnd.year.toString().padLeft(4, '0')}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}";
    await TransactionRepository.insertManual(
      TransactionModel(
        amount: -amount,
        description: "Recovery goal payment",
        date: dateStr,
        type: 'expense',
        categoryName: 'Recovery payment',
      ),
    );
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
      
      // Handle app savings - add leftover money if selected
      if (_addToAppSavings && _baseLeftToSpend > 0) {
        final leftover = (_baseLeftToSpend - _selectedContributionTotal).clamp(0.0, double.infinity);
        if (leftover > 0) {
          final newTotal = await AppSavingsStore.add(leftover);
          scaffold.showSnackBar(
            SnackBar(content: Text("Added \$${leftover.toStringAsFixed(0)} to app savings (total: \$${newTotal.toStringAsFixed(0)})")),
          );
        }
      }
      
      // Handle app savings withdrawal to cover deficit
      if (_useAppSavingsForRecovery && _savingsCoverageAmount > 0) {
        final withdrawn = await AppSavingsStore.withdraw(_savingsCoverageAmount);
        if (withdrawn > 0) {
          if (_deficitFullyCoveredBySavings) {
            scaffold.showSnackBar(
              SnackBar(
                content: Text("Deficit covered! Used \$${withdrawn.toStringAsFixed(0)} from app savings"),
                backgroundColor: Colors.teal,
              ),
            );
          } else {
            scaffold.showSnackBar(
              SnackBar(content: Text("Used \$${withdrawn.toStringAsFixed(0)} from app savings towards deficit")),
            );
          }
        }
      }
      
      // Handle recovery goal creation/update if checkbox is selected AND there's remaining deficit
      if (_createOrAddToRecovery && _deficitAfterSavings > 0) {
        await _processRecoveryGoal();
      }
      
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
  
  /// Creates a new recovery goal or adds to an existing one.
  /// Uses _deficitAfterSavings to account for any savings used to cover the deficit.
  Future<void> _processRecoveryGoal() async {
    final scaffold = ScaffoldMessenger.of(context);
    final effectiveDeficit = _deficitAfterSavings;
    
    if (_recoveryGoals.isNotEmpty) {
      // Add to existing recovery goal
      final existingGoal = _recoveryGoals.first;
      final currentRemaining = (existingGoal.amount - existingGoal.savedAmount).clamp(0.0, double.infinity);
      final newTotal = currentRemaining + effectiveDeficit;
      final newWeeklyPayment = _recoveryWeeks > 0 ? newTotal / _recoveryWeeks : 0.0;
      
      final updated = existingGoal.copyWith(
        amount: existingGoal.savedAmount + newTotal, // Total = already paid + new remaining
        originalDeficit: (existingGoal.originalDeficit ?? existingGoal.amount) + effectiveDeficit,
        recoveryWeeks: _recoveryWeeks,
        weeklyContribution: newWeeklyPayment,
      );
      
      await GoalRepository.update(updated);
      scaffold.showSnackBar(
        SnackBar(
          content: Text("Recovery updated to \$${newTotal.toStringAsFixed(0)} - \$${newWeeklyPayment.toStringAsFixed(2)}/week"),
        ),
      );
    } else {
      // Create new recovery goal
      final weeklyPayment = _recoveryWeeks > 0 ? effectiveDeficit / _recoveryWeeks : 0.0;
      final goal = GoalModel(
        name: "Budget Recovery",
        amount: effectiveDeficit,
        weeklyContribution: weeklyPayment,
        savedAmount: 0,
        goalType: GoalType.recovery,
        originalDeficit: effectiveDeficit,
        recoveryWeeks: _recoveryWeeks,
      );
      
      await GoalRepository.insert(goal);
      scaffold.showSnackBar(
        SnackBar(
          content: Text("Recovery goal created: \$${weeklyPayment.toStringAsFixed(2)}/week for $_recoveryWeeks weeks"),
        ),
      );
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
    // Only get savings goals for the regular contribution section
    final refreshedGoals = (await GoalRepository.getSavingsGoals())
        .where((goal) => !goal.isComplete)
        .toList();
    // Refresh recovery goals separately
    final refreshedRecoveryGoals = await GoalRepository.getActiveRecoveryGoals();
    setState(() {
      _payload = WeeklyOverviewPayload(
        weekStart: _payload.weekStart,
        report: refreshedReport,
        summary: summary,
        goals: refreshedGoals,
      );
      _selectedGoalIds.clear();
      _recoveryGoals = refreshedRecoveryGoals;
      _selectedRecoveryGoalIds.clear();
    });
    _seedControllers();
    _seedRecoveryControllers();
    _autoSelectGoals(emitSetState: true);
  }

  String _formatRange(DateTime start, DateTime end) {
    String fmt(DateTime d) =>
        "${d.day}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}";
    return "${fmt(start)} → ${fmt(end)}";
  }

}

class _OverviewStats extends StatelessWidget {
  final double weeklyBudget;
  final double leftToSpend;

  const _OverviewStats({
    required this.weeklyBudget,
    required this.leftToSpend,
  });

  @override
  Widget build(BuildContext context) {
    final leftPositive = leftToSpend >= 0;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: "Weekly budget",
            value: _currency(weeklyBudget),
            accent: Colors.blueGrey.shade50,
            valueColor: Colors.black87,
            helpTitle: "Weekly Budget",
            helpMessage: "Your discretionary budget for non-budgeted spending.\n\n"
                "Calculation: Income − Total Budgeted\n\n"
                "This is how much you have available for spending outside your budget categories.",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
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
          ),
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
