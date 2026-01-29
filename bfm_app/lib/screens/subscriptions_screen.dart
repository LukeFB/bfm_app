/// ---------------------------------------------------------------------------
/// File: lib/screens/subscriptions_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - First step after bank connection in the onboarding flow.
///   - Shows detected recurring subscriptions for the user to review and select.
///   - Selected subscriptions become budget items with weekly limits.
/// ---------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<_SubscriptionItem> _subscriptions = [];
  final Set<int> _selectedIds = {};
  final Map<int, TextEditingController> _amountCtrls = {};
  CategoryEmojiHelper? _emojiHelper;

  static const double _kWeeksPerMonth = 4.345;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Identify recurring transactions
    await BudgetAnalysisService.identifyRecurringTransactions();

    final allRecurring = await RecurringRepository.getAll();
    final expenses = allRecurring
        .where((r) => r.transactionType.toLowerCase() == 'expense')
        .where((r) {
      final freq = r.frequency.toLowerCase();
      return freq == 'weekly' || freq == 'monthly';
    }).toList();

    if (expenses.isEmpty) {
      if (!mounted) return;
      setState(() {
        _subscriptions = [];
        _loading = false;
      });
      return;
    }

    // Get category names
    final categoryNames = await CategoryRepository.getNamesByIds(
      expenses.map((r) => r.categoryId),
    );

    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();

    // Load existing budgets in edit mode
    Map<int, BudgetModel> existingBudgets = {};
    if (widget.editMode) {
      final budgets = await BudgetRepository.getAll();
      for (final budget in budgets) {
        final recurringId = budget.recurringTransactionId;
        if (recurringId != null) {
          existingBudgets[recurringId] = budget;
        }
      }
    }

    // Build subscription items
    final items = expenses.map((r) {
      final freq = r.frequency.toLowerCase();
      final weeklyAmount =
          freq == 'weekly' ? r.amount : r.amount / _kWeeksPerMonth;
      final description = (r.description ?? '').trim();
      final categoryLabel = (categoryNames[r.categoryId] ?? '').trim();
      final hasCategory = categoryLabel.isNotEmpty &&
          categoryLabel.toLowerCase() != 'uncategorized';
      final fallbackName =
          description.isNotEmpty ? description : 'Recurring expense';
      final label = hasCategory ? categoryLabel : fallbackName;
      final transactionName =
          hasCategory && description.isNotEmpty ? description : null;

      return _SubscriptionItem(
        recurringId: r.id,
        categoryId: r.categoryId,
        label: label,
        transactionName: transactionName,
        frequency: freq,
        amount: r.amount,
        weeklyAmount: double.parse(weeklyAmount.toStringAsFixed(2)),
      );
    }).toList();

    // Sort by frequency then amount
    items.sort((a, b) {
      if (a.frequency != b.frequency) {
        return a.frequency == 'weekly' ? -1 : 1;
      }
      return b.weeklyAmount.compareTo(a.weeklyAmount);
    });

    // Set up controllers and selection state
    final selection = <int>{};
    final controllers = <int, TextEditingController>{};

    for (final item in items) {
      final rid = item.recurringId;
      if (rid == null) continue;

      final existingBudget = existingBudgets[rid];
      final defaultAmount = existingBudget?.weeklyLimit ?? item.weeklyAmount;
      controllers[rid] =
          TextEditingController(text: defaultAmount.toStringAsFixed(2));

      // In edit mode, select items that have existing budgets
      // In create mode, select all by default
      if (widget.editMode) {
        if (existingBudget != null) selection.add(rid);
      } else {
        selection.add(rid);
      }
    }

    // Clean up old controllers
    for (final entry in _amountCtrls.entries) {
      if (!controllers.containsKey(entry.key)) {
        entry.value.dispose();
      }
    }

    if (!mounted) return;

    setState(() {
      _subscriptions = items;
      _selectedIds
        ..clear()
        ..addAll(selection);
      _amountCtrls
        ..clear()
        ..addAll(controllers);
      _emojiHelper = emojiHelper;
      _loading = false;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final periodStart = _mondayOfThisWeek();

    // Clear existing recurring budgets when not in edit mode (fresh onboarding)
    if (!widget.editMode) {
      await BudgetRepository.clearRecurring();
    }

    // Save subscription budgets
    for (final item in _subscriptions) {
      final rid = item.recurringId;
      if (rid == null) continue;

      if (_selectedIds.contains(rid)) {
        final weeklyLimit = _parseAmount(_amountCtrls[rid]?.text ?? '');
        if (weeklyLimit <= 0) continue;

        final budget = BudgetModel(
          categoryId: item.categoryId,
          recurringTransactionId: rid,
          weeklyLimit: weeklyLimit,
          periodStart: periodStart,
        );
        await BudgetRepository.insertOrUpdateRecurring(budget);
      } else {
        // Remove any existing budget for unselected items
        await BudgetRepository.deleteByRecurringId(rid);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    // Navigate to budget build screen
    if (widget.editMode) {
      Navigator.pushReplacementNamed(context, '/budget/edit');
    } else {
      Navigator.pushReplacementNamed(context, '/budget/build');
    }
  }

  String _mondayOfThisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  double _parseAmount(String s) {
    final v = double.tryParse(s.trim());
    if (v == null || v.isNaN || v.isInfinite) return 0.0;
    return max(0.0, v);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTotal = _calculateSelectedTotal();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.editMode,
        title: Text(
            widget.editMode ? 'Edit subscriptions' : 'Review subscriptions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _subscriptions.isEmpty
                      ? _buildEmptyState()
                      : Stack(
                          children: [
                            _buildSubscriptionsList(),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _buildStickyTotal(selectedTotal),
                            ),
                          ],
                        ),
                ),
                _buildFooter(),
                if (_saving) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
    );
  }

  Widget _buildStickyTotal(double selectedTotal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${selectedTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'per week in subscriptions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.autorenew,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No subscriptions found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "We didn't detect any recurring payments yet. You can add them later as more transactions come in.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      children: [
        // Header text
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Select the subscriptions you would like to keep. These will be automatically budgeted for.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
        ),

        // Subscription cards
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _subscriptions.length; i++) ...[
                _buildSubscriptionTile(_subscriptions[i]),
                if (i < _subscriptions.length - 1) 
                  Divider(height: 1, color: Colors.black.withOpacity(0.06)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionTile(_SubscriptionItem item) {
    final rid = item.recurringId;
    if (rid == null) return const SizedBox.shrink();

    final isSelected = _selectedIds.contains(rid);
    final weeklyLimit = _parseAmount(_amountCtrls[rid]?.text ?? '');
    final emoji = _getEmoji(item);
    final paymentLabel = item.frequency == 'monthly'
        ? '\$${item.amount.toStringAsFixed(2)}/month'
        : '\$${item.amount.toStringAsFixed(2)}/week';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleSelection(rid, !isSelected),
      onLongPress: () => _editAmount(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : null,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    width: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : Colors.black87,
                      ),
                    ),
                    if (item.transactionName != null &&
                        item.transactionName!.toLowerCase() !=
                            item.label.toLowerCase())
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.transactionName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Colors.grey.shade100,
                          ),
                          child: Text(
                            paymentLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '→ \$${weeklyLimit.toStringAsFixed(2)}/wk',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Selection indicator instead of checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    width: 2,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black26,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelection(int rid, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(rid);
      } else {
        _selectedIds.remove(rid);
      }
    });
  }

  Future<void> _editAmount(_SubscriptionItem item) async {
    final rid = item.recurringId;
    if (rid == null) return;

    final controller = _amountCtrls[rid];
    if (controller == null) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AmountEditorSheet(
        title: item.label,
        initialValue: controller.text,
        helperText: item.frequency == 'monthly'
            ? 'Original: \$${item.amount.toStringAsFixed(2)}/month'
            : 'Original: \$${item.amount.toStringAsFixed(2)}/week',
      ),
    );

    if (result != null) {
      setState(() {
        controller.text = _parseAmount(result).toStringAsFixed(2);
      });
    }
  }

  String _getEmoji(_SubscriptionItem item) {
    final source = item.label.trim().isNotEmpty
        ? item.label
        : (item.transactionName ?? 'Subscription');
    return _emojiHelper?.emojiForName(source) ??
        CategoryEmojiHelper.defaultEmoji;
  }

  double _calculateSelectedTotal() {
    double sum = 0;
    for (final item in _subscriptions) {
      final rid = item.recurringId;
      if (rid == null) continue;
      if (_selectedIds.contains(rid)) {
        sum += _parseAmount(_amountCtrls[rid]?.text ?? '');
      }
    }
    return sum;
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(
            top: BorderSide(width: 0.5, color: Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Text(
              '${_selectedIds.length} selected',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Continue'),
              onPressed: _saving ? null : _saveAndContinue,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Supporting Classes
// -----------------------------------------------------------------------------

class _SubscriptionItem {
  final int? recurringId;
  final int categoryId;
  final String label;
  final String? transactionName;
  final String frequency;
  final double amount;
  final double weeklyAmount;

  const _SubscriptionItem({
    required this.recurringId,
    required this.categoryId,
    required this.label,
    this.transactionName,
    required this.frequency,
    required this.amount,
    required this.weeklyAmount,
  });
}

class _AmountEditorSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final String? helperText;

  const _AmountEditorSheet({
    required this.title,
    required this.initialValue,
    this.helperText,
  });

  @override
  State<_AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends State<_AmountEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.helperText!,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weekly limit',
              prefixText: '\$',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
