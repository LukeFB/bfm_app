import 'package:flutter/material.dart';
import 'package:bfm_app/models/account_model.dart';
import 'package:bfm_app/models/asset_model.dart';
import 'package:bfm_app/repositories/asset_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/savings_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/models/goal_model.dart';
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
  List<GoalModel> _goals = [];

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimeFrame = prefs.getString(_timeFramePrefKey);
    _selectedTimeFrame = ProfitLossTimeFrame.fromString(savedTimeFrame);
    _initialized = true;
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<SavingsData> _load() async {
    await TransactionSyncService().syncIfStale();
    final appSavings = await AppSavingsStore.getTotal();
    final goals = await GoalRepository.getSavingsGoals();
    if (mounted) {
      setState(() {
        _appSavingsTotal = appSavings;
        _goals = goals;
      });
    }
    return SavingsService.loadSavingsData(timeFrame: _selectedTimeFrame);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _onTimeFrameChanged(ProfitLossTimeFrame? newValue) async {
    if (newValue == null || newValue == _selectedTimeFrame) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeFramePrefKey, newValue.name);
    setState(() {
      _selectedTimeFrame = newValue;
      _future = _load();
    });
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _SavingsContent(
                        data: data,
                        appSavings: _appSavingsTotal,
                        goals: _goals,
                        selectedTimeFrame: _selectedTimeFrame,
                        onTimeFrameChanged: _onTimeFrameChanged,
                        onAddAsset: _showAddAssetDialog,
                        onEditAsset: _showEditAssetDialog,
                        onAssetActions: _showAssetActionsSheet,
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

  double _parseCurrency(String raw) {
    if (raw.trim().isEmpty) return 0.0;
    final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    final value = double.tryParse(sanitized);
    if (value == null || value.isNaN || value.isInfinite) return 0.0;
    return value;
  }

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
  final List<GoalModel> goals;
  final ProfitLossTimeFrame selectedTimeFrame;
  final ValueChanged<ProfitLossTimeFrame?> onTimeFrameChanged;
  final VoidCallback onAddAsset;
  final void Function(AssetModel) onEditAsset;
  final void Function(AssetModel) onAssetActions;

  const _SavingsContent({
    required this.data,
    required this.appSavings,
    required this.goals,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onAddAsset,
    required this.onEditAsset,
    required this.onAssetActions,
  });

  @override
  Widget build(BuildContext context) {
    final profitLoss = data.overallProfitLoss;
    final isProfit = profitLoss >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Overview section ----
        BuxlyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'This Week',
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isProfit
                      ? BuxlyColors.limeGreen.withOpacity(0.15)
                      : BuxlyColors.coralOrange.withOpacity(0.15),
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
                      isProfit ? 'Net Profit' : 'Net Loss',
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
                '${isProfit ? '' : '-'}\$${profitLoss.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: isProfit
                      ? BuxlyColors.darkText
                      : BuxlyColors.coralOrange,
                  fontFamily: BuxlyTheme.fontFamily,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: BuxlyColors.limeGreen,
                      label: 'Income',
                      value: '\$${data.totalIncome.toStringAsFixed(0)}',
                      valueColor: BuxlyColors.limeGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.trending_down_rounded,
                      iconColor: BuxlyColors.coralOrange,
                      label: 'Expenses',
                      value: '\$${data.totalExpenses.toStringAsFixed(0)}',
                      valueColor: BuxlyColors.coralOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Total Saved hero card (always visible)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: appSavings >= 0
                ? BuxlyColors.savingsGradient
                : LinearGradient(
                    colors: [Colors.orange.shade400, Colors.red.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(BuxlyRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appSavings >= 0
                    ? 'Buxly Buffer'
                    : 'Buxly Buffer Deficit',
                style: TextStyle(
                  fontSize: 14,
                  color: BuxlyColors.white.withValues(alpha: 0.85),
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: BuxlyColors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(BuxlyRadius.md),
                    ),
                    child: Icon(
                      appSavings >= 0
                          ? Icons.savings_outlined
                          : Icons.warning_amber_rounded,
                      color: BuxlyColors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    appSavings < 0
                        ? '−\$${appSavings.abs().toStringAsFixed(0)}'
                        : '\$${appSavings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: BuxlyColors.white,
                      fontFamily: BuxlyTheme.fontFamily,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              if (appSavings < 0) ...[
                const SizedBox(height: 8),
                Text(
                  'You\'ve spent more than saved — stay under budget to recover!',
                  style: TextStyle(
                    fontSize: 12,
                    color: BuxlyColors.white.withValues(alpha: 0.8),
                    fontFamily: BuxlyTheme.fontFamily,
                  ),
                ),
              ],
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
              onPressed: () =>
                  Navigator.of(context).pushNamed('/goals'),
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
                      child: _AccountTile(account: account),
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

  Widget _buildTimeFrameDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BuxlyColors.offWhite,
        borderRadius: BorderRadius.circular(BuxlyRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProfitLossTimeFrame>(
          value: selectedTimeFrame,
          onChanged: onTimeFrameChanged,
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

  String _targetDateLabel(GoalModel goal) {
    if (goal.weeklyContribution <= 0 || goal.amount <= goal.savedAmount) {
      return '';
    }
    final remaining = goal.amount - goal.savedAmount;
    final weeks = (remaining / goal.weeklyContribution).ceil();
    final target = DateTime.now().add(Duration(days: weeks * 7));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Target: ${months[target.month - 1]} ${target.year}';
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
// Mini stat card
// ---------------------------------------------------------------------------

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(BuxlyRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: BuxlyColors.midGrey,
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountModel account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final balance = account.balanceCurrent;
    final isNegative = balance < 0;

    return BuxlyCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BuxlyIconContainer(
            icon: _accountIcon(account.type),
            color: _accountColor(account.type),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: BuxlyTheme.fontFamily,
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
              color: isNegative ? BuxlyColors.coralOrange : BuxlyColors.darkText,
              fontFamily: BuxlyTheme.fontFamily,
            ),
          ),
        ],
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
