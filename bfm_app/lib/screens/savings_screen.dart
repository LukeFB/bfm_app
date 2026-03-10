import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/models/account_model.dart';
import 'package:bfm_app/utils/format_helpers.dart';
import 'package:bfm_app/widgets/buxly_header.dart';
import 'package:bfm_app/models/asset_model.dart';
import 'package:bfm_app/repositories/asset_repository.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/budget_buffer_store.dart';
import 'package:bfm_app/services/buxly_buffer_budget_store.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/savings_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

const String _timeFramePrefKey = 'savings_profit_loss_time_frame';

class SavingsScreen extends StatefulWidget {
  final bool embedded;
  const SavingsScreen({super.key, this.embedded = false});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late Future<SavingsData> _future;
  ProfitLossTimeFrame _selectedTimeFrame = ProfitLossTimeFrame.allTime;
  bool _initialized = false;
  double _appSavingsTotal = 0.0;
  double _perBudgetBufferTotal = 0.0;
  List<GoalModel> _goals = [];
  DateTime? _appStartDate;
  SavingsData? _cachedData;
  final ScrollController _scrollController = ScrollController();
  int? _bufferBudgetWeeks;
  double _bufferBudgetTargetWeekly = 0;

  double get _totalIncome {
    final ts = _cachedData?.profitLossTimeSeries;
    if (ts == null || ts.isEmpty) return _cachedData?.totalIncome ?? 0;
    final start = _selectedTimeFrame.startDate;
    return ts
        .where((p) => !p.date.isBefore(start))
        .fold(0.0, (s, p) => s + p.income);
  }

  double get _totalExpenses {
    final ts = _cachedData?.profitLossTimeSeries;
    if (ts == null || ts.isEmpty) return _cachedData?.totalExpenses ?? 0;
    final start = _selectedTimeFrame.startDate;
    return ts
        .where((p) => !p.date.isBefore(start))
        .fold(0.0, (s, p) => s + p.expenses);
  }

  double get _profitLoss => _totalIncome - _totalExpenses;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimeFrame = prefs.getString(_timeFramePrefKey);
    _selectedTimeFrame = ProfitLossTimeFrame.fromString(savedTimeFrame);

    final storedDate = prefs.getString('app_start_date');
    if (storedDate != null) {
      _appStartDate = DateTime.tryParse(storedDate);
    }
    if (_appStartDate == null) {
      _appStartDate = DateTime.now();
      await prefs.setString(
          'app_start_date', _appStartDate!.toIso8601String());
    }

    _initialized = true;
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<SavingsData> _load() async {
    await TransactionSyncService().syncIfStale();
    final appSavings = await AppSavingsStore.getTotal();
    final bufferBalances = await BudgetBufferStore.getAll();
    final bufferTotal = bufferBalances.values.fold<double>(0, (s, v) => s + v);
    final goals = await GoalRepository.getSavingsGoals();
    final data = await SavingsService.loadSavingsData(
        timeFrame: _selectedTimeFrame);

    // --- Buffer budget computation ---
    final weeklyIncome = await DashboardService.weeklyIncomeLastWeek();
    final totalBudgets = await BudgetRepository.getTotalWeeklyBudget();
    final goalBudgets = await BudgetRepository.getGoalWeeklyBudgetTotal();
    final existingBufferBudget = await BuxlyBufferBudgetStore.getExisting();
    final currentBufferWeekly = existingBufferBudget?.weeklyLimit ?? 0.0;

    // Unbudgeted recurring expenses
    final allRecurring = await RecurringRepository.getAll();
    final allBudgets = await BudgetRepository.getAll();
    final budgetedRecurringIds = allBudgets
        .where((b) => b.recurringTransactionId != null)
        .map((b) => b.recurringTransactionId!)
        .toSet();
    double unbudgetedRecurringWeekly = 0;
    for (final r in allRecurring) {
      if (r.transactionType.toLowerCase() != 'expense') continue;
      if (r.id != null && budgetedRecurringIds.contains(r.id!)) continue;
      final freq = r.frequency.toLowerCase();
      if (freq != 'weekly' && freq != 'monthly') continue;
      unbudgetedRecurringWeekly +=
          freq == 'weekly' ? r.amount : r.amount / 4.345;
    }

    final disposable = weeklyIncome -
        (totalBudgets - currentBufferWeekly) -
        goalBudgets -
        unbudgetedRecurringWeekly;
    final targetWeekly = disposable > 0 ? disposable * 0.25 : 0.0;

    int? newBufferWeeks;
    double newTargetWeekly = 0;
    if (appSavings < 0 && targetWeekly > 0) {
      final storedWeeks = await BuxlyBufferBudgetStore.getWeeks();
      final defaultWeeks =
          (appSavings.abs() / targetWeekly).ceil().clamp(1, 104);
      newBufferWeeks = storedWeeks ?? defaultWeeks;
      newTargetWeekly = targetWeekly;
      final weeklyAmount = appSavings.abs() / newBufferWeeks;
      await BuxlyBufferBudgetStore.save(
          weeks: newBufferWeeks, weeklyAmount: weeklyAmount);
    } else if (appSavings >= 0 && existingBufferBudget != null) {
      await BuxlyBufferBudgetStore.clear();
    }

    if (mounted) {
      setState(() {
        _appSavingsTotal = appSavings;
        _perBudgetBufferTotal = bufferTotal;
        _goals = goals;
        _cachedData = data;
        _bufferBudgetWeeks = newBufferWeeks;
        _bufferBudgetTargetWeekly = newTargetWeekly;
      });
    }
    return data;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _toggleAccountExclusion(
      AccountModel account, bool included) async {
    if (account.id == null) return;

    // When excluding (included == false), check for linked budgets/recurring
    if (!included) {
      final counts = await AccountRepository.getLinkedBudgetAndRecurringCounts(
        account.akahuId,
      );
      if (!mounted) return;

      if (counts.budgetCount > 0 || counts.recurringCount > 0) {
        final parts = <String>[];
        if (counts.budgetCount > 0) {
          parts.add('${counts.budgetCount} budget${counts.budgetCount == 1 ? '' : 's'}');
        }
        if (counts.recurringCount > 0) {
          parts.add('${counts.recurringCount} recurring payment${counts.recurringCount == 1 ? '' : 's'}');
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exclude account?'),
            content: Text(
              '"${account.name}" has ${parts.join(' and ')} linked to its '
              'transactions. Excluding it will remove those transactions from '
              'all calculations including budget tracking.\n\n'
              'You can re-include this account at any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exclude'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }

    await AccountRepository.setExcluded(
      id: account.id!,
      excluded: !included,
    );
    if (!mounted) return;
    // Reload data in the background without replacing the future so the
    // FutureBuilder doesn't show the spinner and reset the scroll position.
    _load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onTimeFrameChanged(ProfitLossTimeFrame? newValue) async {
    if (newValue == null || newValue == _selectedTimeFrame) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeFramePrefKey, newValue.name);
    setState(() => _selectedTimeFrame = newValue);
  }

  Future<void> _onBufferBudgetWeeksChanged(int newWeeks) async {
    if (newWeeks < 1 || _appSavingsTotal >= 0) return;
    final weeklyAmount = _appSavingsTotal.abs() / newWeeks;
    await BuxlyBufferBudgetStore.save(
        weeks: newWeeks, weeklyAmount: weeklyAmount);
    if (mounted) setState(() => _bufferBudgetWeeks = newWeeks);
  }

  Future<void> _openSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (mounted) _refresh();
  }

  Widget _buildHeader() {
    return BuxlyHeader(onSettingsPressed: _openSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BuxlyColors.offWhite,
      body: SafeArea(
        child: !_initialized
            ? const Center(
                child: CircularProgressIndicator(color: BuxlyColors.teal))
            : FutureBuilder<SavingsData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: BuxlyColors.teal),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: BuxlyColors.coralOrange),
                          const SizedBox(height: 16),
                          Text(
                            "Error loading data:\n${snap.error}",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snap.data!;
                  return RefreshIndicator(
                    color: BuxlyColors.teal,
                    onRefresh: _forceSync,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 12),
                          _SavingsContent(
                        data: _cachedData ?? data,
                        appSavings: _appSavingsTotal,
                        perBudgetBufferTotal: _perBudgetBufferTotal,
                        goals: _goals,
                        totalIncome: _totalIncome,
                        totalExpenses: _totalExpenses,
                        profitLoss: _profitLoss,
                        selectedTimeFrame: _selectedTimeFrame,
                        onTimeFrameChanged: _onTimeFrameChanged,
                        onAddAsset: _showAddAssetDialog,
                        onEditAsset: _showEditAssetDialog,
                        onAssetActions: _showAssetActionsSheet,
                        onAccountToggle: _toggleAccountExclusion,
                        appStartDate: _appStartDate,
                        bufferBudgetWeeks: _bufferBudgetWeeks,
                        bufferBudgetTargetWeekly: _bufferBudgetTargetWeekly,
                        onBufferBudgetWeeksChanged: _onBufferBudgetWeeksChanged,
                      ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Asset dialogs (kept from original)
  // ---------------------------------------------------------------------------

  void _showAddAssetDialog() {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final notesController = TextEditingController();
    AssetCategory selectedCategory = AssetCategory.cash;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Emergency Fund, Toyota Corolla',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AssetCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AssetCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_getAssetCategoryIcon(cat),
                              size: 18,
                              color: _getAssetCategoryColor(cat)),
                          const SizedBox(width: 8),
                          Text(cat.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    prefixText: '\$ ',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Any additional details',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                final value = _parseCurrency(valueController.text);
                final notes = notesController.text.trim();
                final asset = AssetModel(
                  name: name,
                  category: selectedCategory,
                  value: value,
                  notes: notes.isEmpty ? null : notes,
                );
                await AssetRepository.insert(asset);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _refresh();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAssetDialog(AssetModel asset) {
    final nameController = TextEditingController(text: asset.name);
    final valueController =
        TextEditingController(text: asset.value.toStringAsFixed(2));
    final notesController = TextEditingController(text: asset.notes ?? '');
    AssetCategory selectedCategory = asset.category;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AssetCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AssetCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_getAssetCategoryIcon(cat),
                              size: 18,
                              color: _getAssetCategoryColor(cat)),
                          const SizedBox(width: 8),
                          Text(cat.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                final value = _parseCurrency(valueController.text);
                final notes = notesController.text.trim();
                final updatedAsset = asset.copyWith(
                  name: name,
                  category: selectedCategory,
                  value: value,
                  notes: notes.isEmpty ? null : notes,
                );
                await AssetRepository.update(updatedAsset);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _refresh();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssetActionsSheet(AssetModel asset) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditAssetDialog(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: BuxlyColors.coralOrange),
              title: const Text('Delete',
                  style: TextStyle(color: BuxlyColors.coralOrange)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Asset?'),
                    content: Text(
                        'Are you sure you want to delete "${asset.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: BuxlyColors.coralOrange),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && asset.id != null) {
                  await AssetRepository.delete(asset.id!);
                  _refresh();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  double _parseCurrency(String raw) => parseCurrency(raw);

  IconData _getAssetCategoryIcon(AssetCategory category) {
    switch (category) {
      case AssetCategory.cash:
        return Icons.account_balance_wallet_outlined;
      case AssetCategory.vehicle:
        return Icons.directions_car_outlined;
      case AssetCategory.property:
        return Icons.home_outlined;
      case AssetCategory.investment:
        return Icons.trending_up_outlined;
      case AssetCategory.kiwisaver:
        return Icons.elderly_outlined;
      case AssetCategory.valuables:
        return Icons.diamond_outlined;
      case AssetCategory.other:
        return Icons.category_outlined;
    }
  }

  Color _getAssetCategoryColor(AssetCategory category) {
    switch (category) {
      case AssetCategory.cash:
        return BuxlyColors.limeGreen;
      case AssetCategory.vehicle:
        return BuxlyColors.skyBlue;
      case AssetCategory.property:
        return BuxlyColors.coralOrange;
      case AssetCategory.investment:
        return BuxlyColors.teal;
      case AssetCategory.kiwisaver:
        return BuxlyColors.blushPink;
      case AssetCategory.valuables:
        return BuxlyColors.sunshineYellow;
      case AssetCategory.other:
        return BuxlyColors.midGrey;
    }
  }
}

// ---------------------------------------------------------------------------
// Overview Tab
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Combined savings content (single scrollable view)
// ---------------------------------------------------------------------------

class _SavingsContent extends StatelessWidget {
  final SavingsData data;
  final double appSavings;
  final double perBudgetBufferTotal;
  final List<GoalModel> goals;
  final double totalIncome;
  final double totalExpenses;
  final double profitLoss;
  final ProfitLossTimeFrame selectedTimeFrame;
  final ValueChanged<ProfitLossTimeFrame?> onTimeFrameChanged;
  final VoidCallback onAddAsset;
  final void Function(AssetModel) onEditAsset;
  final void Function(AssetModel) onAssetActions;
  final void Function(AccountModel, bool) onAccountToggle;
  final DateTime? appStartDate;
  final int? bufferBudgetWeeks;
  final double bufferBudgetTargetWeekly;
  final ValueChanged<int>? onBufferBudgetWeeksChanged;

  const _SavingsContent({
    required this.data,
    required this.appSavings,
    required this.perBudgetBufferTotal,
    required this.goals,
    required this.totalIncome,
    required this.totalExpenses,
    required this.profitLoss,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onAddAsset,
    required this.onEditAsset,
    required this.onAssetActions,
    required this.onAccountToggle,
    this.appStartDate,
    this.bufferBudgetWeeks,
    this.bufferBudgetTargetWeekly = 0,
    this.onBufferBudgetWeeksChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Buxly Buffer card ----
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BuxlyRadius.lg),
            color: Colors.white,
            border: appSavings < 0
                ? Border.all(color: Colors.orange.shade400, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.savings, color: BuxlyColors.teal, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Buxly Buffer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: BuxlyTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(width: 4),
                  HelpIconTooltip(
                    title: 'Buxly Buffer',
                    message:
                        'Your Buxly Buffer tracks money saved from your '
                        'non-essential spending each week. When you stay '
                        'under your Left to Spend, the leftover is added '
                        'to your buffer.\n\n'
                        'If you overspend, the buffer absorbs the cost. '
                        'If it goes negative, you\'ve spent more than '
                        'you\'ve saved.\n\n'
                        'When your buffer is negative, the Buffer Budget '
                        'automatically sets aside money each week to help '
                        'you recover. It\'s calculated as 25% of your '
                        'disposable income (income minus budgets and '
                        'recurring expenses), and the number of weeks '
                        'adjusts accordingly.\n\n'
                        'You can change the weeks to pay it back faster '
                        'or slower. This budget won\'t appear on your '
                        'Budgets screen but will reduce your Left to '
                        'Spend on the dashboard.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (appSavings < 0 && bufferBudgetWeeks != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '−\$${appSavings.abs().toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: BuxlyColors.coralOrange,
                              fontFamily: BuxlyTheme.fontFamily,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'Non-essential\nexpense buffer',
                            style: TextStyle(
                              fontSize: 12,
                              color: BuxlyColors.midGrey,
                              fontFamily: BuxlyTheme.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBufferBudgetCard(),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  appSavings < 0
                      ? '−\$${appSavings.abs().toStringAsFixed(0)}'
                      : '\$${appSavings.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: appSavings < 0
                        ? BuxlyColors.coralOrange
                        : BuxlyColors.darkText,
                    fontFamily: BuxlyTheme.fontFamily,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Non-essential expense buffer',
                  style: TextStyle(
                    fontSize: 13,
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                '\$${perBudgetBufferTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: BuxlyColors.darkText,
                  fontFamily: BuxlyTheme.fontFamily,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Essential expense buffer',
                style: TextStyle(
                  fontSize: 13,
                  color: BuxlyColors.midGrey,
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---- Goals section ----
        Row(
          children: [
            const Text(
              'Savings Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BuxlyColors.darkText,
                fontFamily: BuxlyTheme.fontFamily,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/goals'),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: BuxlyColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        BuxlyCard(
          child: goals.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const BuxlyIconContainer(
                          icon: Icons.savings_outlined,
                          color: BuxlyColors.teal,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No goals yet',
                          style: TextStyle(
                            color: BuxlyColors.midGrey,
                            fontFamily: BuxlyTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < goals.length; i++) ...[
                      if (i > 0)
                        Divider(
                          color: BuxlyColors.midGrey.withOpacity(0.15),
                          height: 24,
                        ),
                      Builder(builder: (context) {
                        final goal = goals[i];
                        final progress = goal.progressFraction;
                        final percent = (progress * 100).toInt();
                        final emoji = goalEmoji(goal);
                        final barColor = _goalBarColor(i);
                        final targetLabel = _targetDateLabel(goal);

                        return Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: barColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 22)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal.name.isEmpty
                                            ? 'Goal'
                                            : goal.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: BuxlyTheme.fontFamily,
                                        ),
                                      ),
                                      if (targetLabel.isNotEmpty)
                                        Text(
                                          targetLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: BuxlyColors.midGrey,
                                            fontFamily:
                                                BuxlyTheme.fontFamily,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$percent%',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: BuxlyColors.darkText,
                                        fontFamily: BuxlyTheme.fontFamily,
                                      ),
                                    ),
                                    Text(
                                      '\$${goal.savedAmount.toStringAsFixed(0)}/\$${goal.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: BuxlyColors.midGrey,
                                        fontFamily: BuxlyTheme.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            BuxlyProgressBar(
                              value: progress,
                              color: barColor,
                              height: 6,
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: 20),

        // ---- Profit / Loss with chart ----
        _ProfitLossCard(
          chartData: data.profitLossTimeSeries,
          appStartDate: appStartDate,
          profitLoss: profitLoss,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          selectedTimeFrame: selectedTimeFrame,
          onTimeFrameChanged: onTimeFrameChanged,
        ),

        const SizedBox(height: 20),

        // ---- Accounts section ----
        if (data.accounts.isNotEmpty) ...[
          const Text(
            'Connected Accounts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BuxlyColors.darkText,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toggle off to exclude an account from all calculations.',
            style: TextStyle(
              fontSize: 12,
              color: BuxlyColors.midGrey,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          ...data.accountsByBank.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                ...entry.value.map((account) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AccountTile(
                        account: account,
                        onToggle: (included) =>
                            onAccountToggle(account, included),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            );
          }),
          const SizedBox(height: 16),
        ],

        // Assets
        Row(
          children: [
            const Text(
              'My Assets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BuxlyColors.darkText,
                fontFamily: BuxlyTheme.fontFamily,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: BuxlyColors.teal),
              onPressed: onAddAsset,
              tooltip: 'Add asset',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data.assets.isEmpty)
          BuxlyCard(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Icon(Icons.add_box_outlined,
                      size: 40, color: BuxlyColors.midGrey),
                  const SizedBox(height: 8),
                  Text(
                    'No assets added yet',
                    style: TextStyle(
                      color: BuxlyColors.midGrey,
                      fontFamily: BuxlyTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          )
        else
          ...data.assets.map((asset) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onEditAsset(asset),
                  onLongPress: () => onAssetActions(asset),
                  borderRadius: BorderRadius.circular(BuxlyRadius.lg),
                  child: _AssetTile(asset: asset),
                ),
              )),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBufferBudgetCard() {
    final weeks = bufferBudgetWeeks ?? 1;
    final weeklyAmount = appSavings.abs() / weeks;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BuxlyColors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buffer Budget',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BuxlyColors.darkText,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${weeklyAmount.toStringAsFixed(0)}/wk',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: BuxlyColors.teal,
              fontFamily: BuxlyTheme.fontFamily,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _weeksButton(Icons.remove, () {
                if (weeks > 1) {
                  onBufferBudgetWeeksChanged?.call(weeks - 1);
                }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$weeks wks',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BuxlyColors.darkText,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              ),
              _weeksButton(Icons.add, () {
                onBufferBudgetWeeksChanged?.call(weeks + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeksButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: BuxlyColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: BuxlyColors.teal),
      ),
    );
  }

  String _targetDateLabel(GoalModel goal) {
    if (goal.weeklyContribution <= 0 || goal.amount <= goal.savedAmount) {
      return '';
    }
    final remaining = goal.amount - goal.savedAmount;
    final weeks = (remaining / goal.weeklyContribution).ceil();
    final target = DateTime.now().add(Duration(days: weeks * 7));
    return 'Target: ${kMonthAbbreviations[target.month - 1]} ${target.year}';
  }

  Color _goalBarColor(int index) {
    const colors = [
      BuxlyColors.skyBlue,
      BuxlyColors.limeGreen,
      BuxlyColors.teal,
      BuxlyColors.sunshineYellow,
      BuxlyColors.coralOrange,
    ];
    return colors[index % colors.length];
  }
}

// ---------------------------------------------------------------------------
// Profit/Loss Card with interactive chart
// ---------------------------------------------------------------------------

class _ProfitLossCard extends StatefulWidget {
  final List<ProfitLossPoint> chartData;
  final DateTime? appStartDate;
  final double profitLoss;
  final double totalIncome;
  final double totalExpenses;
  final ProfitLossTimeFrame selectedTimeFrame;
  final ValueChanged<ProfitLossTimeFrame?> onTimeFrameChanged;

  const _ProfitLossCard({
    required this.chartData,
    this.appStartDate,
    required this.profitLoss,
    required this.totalIncome,
    required this.totalExpenses,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
  });

  @override
  State<_ProfitLossCard> createState() => _ProfitLossCardState();
}

class _ProfitLossCardState extends State<_ProfitLossCard> {
  int? _selectedIndex;
  late List<ProfitLossPoint> _visibleData;
  late List<double> _cumulativeNet;
  late List<double> _cumulativeIncome;
  late List<double> _cumulativeExpenses;

  @override
  void initState() {
    super.initState();
    _visibleData = _filterData();
    _computeCumulatives();
  }

  @override
  void didUpdateWidget(covariant _ProfitLossCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimeFrame != widget.selectedTimeFrame ||
        oldWidget.chartData != widget.chartData) {
      _visibleData = _filterData();
      _computeCumulatives();
      _selectedIndex = null;
    }
  }

  List<ProfitLossPoint> _filterData() {
    final start = widget.selectedTimeFrame.startDate;
    return widget.chartData
        .where((p) => !p.date.isBefore(start))
        .toList();
  }

  void _computeCumulatives() {
    double runningNet = 0;
    double runningIncome = 0;
    double runningExpenses = 0;
    _cumulativeNet = [];
    _cumulativeIncome = [];
    _cumulativeExpenses = [];
    for (final p in _visibleData) {
      runningNet += p.net;
      runningIncome += p.income;
      runningExpenses += p.expenses;
      _cumulativeNet.add(runningNet);
      _cumulativeIncome.add(runningIncome);
      _cumulativeExpenses.add(runningExpenses);
    }
  }

  double get _displayPL => _selectedIndex != null
      ? _cumulativeNet[_selectedIndex!]
      : widget.profitLoss;

  double get _displayIncome => _selectedIndex != null
      ? _cumulativeIncome[_selectedIndex!]
      : widget.totalIncome;

  double get _displayExpenses => _selectedIndex != null
      ? _cumulativeExpenses[_selectedIndex!]
      : widget.totalExpenses;

  void _handleTouch(Offset local, double width) {
    if (_visibleData.length < 2) return;
    final ratio = (local.dx / width).clamp(0.0, 1.0);
    final idx = (ratio * (_visibleData.length - 1))
        .round()
        .clamp(0, _visibleData.length - 1);
    if (idx != _selectedIndex) setState(() => _selectedIndex = idx);
  }

  void _clearSelection() {
    if (_selectedIndex != null) setState(() => _selectedIndex = null);
  }

  String _selectedPeriodLabel() {
    if (_selectedIndex == null) return '';
    final d = _visibleData[_selectedIndex!].date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Week of ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final pl = _displayPL;
    final isProfit = pl >= 0;
    final isSelected = _selectedIndex != null;

    return BuxlyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Profit / Loss',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: BuxlyColors.darkText,
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
              const Spacer(),
              _buildTimeFrameDropdown(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isProfit
                      ? BuxlyColors.limeGreen
                      : BuxlyColors.coralOrange)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(BuxlyRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isProfit
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: isProfit
                      ? BuxlyColors.limeGreen
                      : BuxlyColors.coralOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  isSelected
                      ? _selectedPeriodLabel()
                      : (isProfit ? 'Net Profit' : 'Net Loss'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isProfit
                        ? BuxlyColors.limeGreen
                        : BuxlyColors.coralOrange,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isProfit ? '' : '-'}\$${pl.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: isProfit ? BuxlyColors.darkText : BuxlyColors.coralOrange,
              fontFamily: BuxlyTheme.fontFamily,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  icon: Icons.arrow_upward_rounded,
                  color: BuxlyColors.limeGreen,
                  label: 'Income',
                  value: '\$${_displayIncome.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactStat(
                  icon: Icons.arrow_downward_rounded,
                  color: BuxlyColors.coralOrange,
                  label: 'Expenses',
                  value: '\$${_displayExpenses.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFrameDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BuxlyColors.offWhite,
        borderRadius: BorderRadius.circular(BuxlyRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProfitLossTimeFrame>(
          value: widget.selectedTimeFrame,
          onChanged: widget.onTimeFrameChanged,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: BuxlyColors.midGrey, size: 20),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: BuxlyColors.midGrey,
            fontFamily: BuxlyTheme.fontFamily,
          ),
          items: ProfitLossTimeFrame.values.map((tf) {
            return DropdownMenuItem<ProfitLossTimeFrame>(
              value: tf,
              child: Text(tf.label),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final data = _visibleData;
    if (data.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Not enough data for chart',
            style: TextStyle(
              color: BuxlyColors.midGrey,
              fontSize: 12,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), _cumulativeNet[i]));
    }

    double? appStartX;
    if (widget.appStartDate != null && data.isNotEmpty) {
      final appStart = widget.appStartDate!;
      if (!appStart.isBefore(data.first.date)) {
        for (int i = 0; i < data.length; i++) {
          if (!data[i].date.isBefore(appStart)) {
            appStartX = i.toDouble();
            break;
          }
        }
        appStartX ??= (data.length - 1).toDouble();
      }
    }

    final yValues = spots.map((s) => s.y).toList();
    final dataMaxY = yValues.reduce(max);
    final dataMinY = yValues.reduce(min);
    final range = (dataMaxY - dataMinY).abs();
    final yPad = range == 0 ? 100.0 : range * 0.15;

    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      color: BuxlyColors.teal,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: BuxlyColors.limeGreen.withOpacity(0.15),
        cutOffY: 0,
        applyCutOffY: true,
      ),
      aboveBarData: BarAreaData(
        show: true,
        color: BuxlyColors.coralOrange.withOpacity(0.15),
        cutOffY: 0,
        applyCutOffY: true,
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
        onTapUp: (_) => _clearSelection(),
        onHorizontalDragUpdate: (d) =>
            _handleTouch(d.localPosition, constraints.maxWidth),
        onHorizontalDragEnd: (_) => _clearSelection(),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              clipData: const FlClipData.all(),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: dataMinY - yPad,
              maxY: dataMaxY + yPad,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _xInterval(data.length),
                    getTitlesWidget: (value, meta) =>
                        _bottomTitle(value, meta, data),
                  ),
                ),
              ),
              lineBarsData: [barData],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: BuxlyColors.midGrey.withOpacity(0.3),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
                verticalLines: [
                  if (appStartX != null)
                    VerticalLine(
                      x: appStartX,
                      color: BuxlyColors.teal.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: VerticalLineLabel(
                        show: true,
                        labelResolver: (_) => 'Started',
                        alignment: Alignment.topRight,
                        style: TextStyle(
                          color: BuxlyColors.midGrey,
                          fontSize: 10,
                          fontFamily: BuxlyTheme.fontFamily,
                        ),
                      ),
                    ),
                  if (_selectedIndex != null)
                    VerticalLine(
                      x: _selectedIndex!.toDouble(),
                      color: BuxlyColors.darkText.withOpacity(0.35),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                enabled: false,
                getTouchedSpotIndicator: (bar, idxs) {
                  return idxs.map((i) {
                    return TouchedSpotIndicatorData(
                      const FlLine(
                          color: Colors.transparent, strokeWidth: 0),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, b, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: BuxlyColors.teal,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (_) => [null],
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 0,
                ),
              ),
              showingTooltipIndicators: _selectedIndex != null
                  ? [
                      ShowingTooltipIndicators([
                        LineBarSpot(
                            barData, 0, spots[_selectedIndex!]),
                      ]),
                    ]
                  : [],
            ),
          ),
        ),
      );
    });
  }

  static double _xInterval(int count) {
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    return (count / 5).ceilToDouble();
  }

  static Widget _bottomTitle(
      double value, TitleMeta meta, List<ProfitLossPoint> data) {
    final idx = value.toInt();
    if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
    final date = data[idx].date;

    final sameYear = data.first.date.year == data.last.date.year;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final label = sameYear
        ? months[date.month - 1]
        : "${months[date.month - 1]} '${date.year % 100}";

    return SideTitleWidget(
      meta: meta,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: BuxlyColors.midGrey,
          fontFamily: BuxlyTheme.fontFamily,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact stat row item
// ---------------------------------------------------------------------------

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _CompactStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: BuxlyColors.midGrey,
                fontFamily: BuxlyTheme.fontFamily,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: BuxlyTheme.fontFamily,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountModel account;
  final ValueChanged<bool>? onToggle;
  const _AccountTile({required this.account, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final balance = account.balanceCurrent;
    final isNegative = balance < 0;
    final isIncluded = !account.excluded;

    return AnimatedOpacity(
      opacity: isIncluded ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: BuxlyCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            BuxlyIconContainer(
              icon: _accountIcon(account.type),
              color: isIncluded
                  ? _accountColor(account.type)
                  : BuxlyColors.midGrey,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: BuxlyTheme.fontFamily,
                      color: isIncluded
                          ? BuxlyColors.darkText
                          : BuxlyColors.midGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (account.maskedAccountNumber != null)
                    Text(
                      account.maskedAccountNumber!,
                      style: TextStyle(
                        fontSize: 11,
                        color: BuxlyColors.midGrey,
                        fontFamily: BuxlyTheme.fontFamily,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${isNegative ? '-' : ''}\$${balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: !isIncluded
                    ? BuxlyColors.midGrey
                    : isNegative
                        ? BuxlyColors.coralOrange
                        : BuxlyColors.darkText,
                fontFamily: BuxlyTheme.fontFamily,
              ),
            ),
            if (onToggle != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 24,
                child: Switch.adaptive(
                  value: isIncluded,
                  onChanged: onToggle,
                  activeTrackColor: BuxlyColors.teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _accountIcon(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return Icons.account_balance_wallet_outlined;
      case AccountType.savings:
        return Icons.savings_outlined;
      case AccountType.creditCard:
        return Icons.credit_card_outlined;
      case AccountType.kiwiSaver:
        return Icons.elderly_outlined;
      case AccountType.investment:
        return Icons.trending_up_outlined;
      case AccountType.loan:
        return Icons.money_off_outlined;
      case AccountType.other:
        return Icons.account_balance_outlined;
    }
  }

  Color _accountColor(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return BuxlyColors.teal;
      case AccountType.savings:
        return BuxlyColors.limeGreen;
      case AccountType.creditCard:
        return BuxlyColors.coralOrange;
      case AccountType.kiwiSaver:
        return BuxlyColors.blushPink;
      case AccountType.investment:
        return BuxlyColors.skyBlue;
      case AccountType.loan:
        return BuxlyColors.hotPink;
      case AccountType.other:
        return BuxlyColors.midGrey;
    }
  }
}

class _AssetTile extends StatelessWidget {
  final AssetModel asset;
  const _AssetTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    return BuxlyCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BuxlyIconContainer(
            icon: _assetIcon(asset.category),
            color: _assetColor(asset.category),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
                Text(
                  asset.category.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: BuxlyColors.midGrey,
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${asset.value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BuxlyColors.limeGreen,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  IconData _assetIcon(AssetCategory cat) {
    switch (cat) {
      case AssetCategory.cash:
        return Icons.account_balance_wallet_outlined;
      case AssetCategory.vehicle:
        return Icons.directions_car_outlined;
      case AssetCategory.property:
        return Icons.home_outlined;
      case AssetCategory.investment:
        return Icons.trending_up_outlined;
      case AssetCategory.kiwisaver:
        return Icons.elderly_outlined;
      case AssetCategory.valuables:
        return Icons.diamond_outlined;
      case AssetCategory.other:
        return Icons.category_outlined;
    }
  }

  Color _assetColor(AssetCategory cat) {
    switch (cat) {
      case AssetCategory.cash:
        return BuxlyColors.limeGreen;
      case AssetCategory.vehicle:
        return BuxlyColors.skyBlue;
      case AssetCategory.property:
        return BuxlyColors.coralOrange;
      case AssetCategory.investment:
        return BuxlyColors.teal;
      case AssetCategory.kiwisaver:
        return BuxlyColors.blushPink;
      case AssetCategory.valuables:
        return BuxlyColors.sunshineYellow;
      case AssetCategory.other:
        return BuxlyColors.midGrey;
    }
  }
}
