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
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _waitingForSync = false;
  bool _loading = true;
  bool _saving = false;
  bool _syncFailed = false;
  List<_SubscriptionItem> _subscriptions = [];
  final Set<int> _selectedIds = {};
  final Map<int, TextEditingController> _amountCtrls = {};
  final Map<int, String> _nameOverrides = {};
  CategoryEmojiHelper? _emojiHelper;

  static const double _kWeeksPerMonth = 4.345;

  @override
  void initState() {
    super.initState();
    _ensureTransactionsAndLoad();
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ensures transactions exist in the local DB before analysing them.
  /// Retries with delays after a fresh bank connection since Akahu needs
  /// time to pull transactions from the bank.
  Future<void> _ensureTransactionsAndLoad() async {
    setState(() {
      _loading = true;
      _waitingForSync = true;
      _syncFailed = false;
    });

    // Check if we already have transactions locally
    final existing = await TransactionRepository.getRecent(1);
    if (existing.isNotEmpty) {
      if (!mounted) return;
      setState(() => _waitingForSync = false);
      await _loadRecurring();
      return;
    }

    // No local transactions — sync with retries. After a fresh Akahu
    // connection the backend needs time to fetch bank data.
    const retryDelays = [0, 10, 15, 20, 20];
    for (var i = 0; i < retryDelays.length; i++) {
      if (!mounted) return;
      if (retryDelays[i] > 0) {
        await Future.delayed(Duration(seconds: retryDelays[i]));
      }

      if (TransactionSyncService.isSyncing) {
        try { await TransactionSyncService.waitForSync(); } catch (_) {}
      } else {
        try { await TransactionSyncService().syncNow(); } catch (_) {}
      }

      if (!mounted) return;
      final afterSync = await TransactionRepository.getRecent(1);
      if (afterSync.isNotEmpty) break;
    }

    if (!mounted) return;
    final finalCheck = await TransactionRepository.getRecent(1);
    if (finalCheck.isEmpty) {
      setState(() => _syncFailed = true);
    }

    setState(() => _waitingForSync = false);
    await _loadRecurring();
  }

  Future<void> _loadRecurring() async {
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

      if (widget.editMode) {
        if (existingBudget != null) {
          selection.add(rid);
          if (existingBudget.label != null && existingBudget.label!.trim().isNotEmpty) {
            _nameOverrides[rid] = existingBudget.label!;
          }
        }
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

    // Save subscription budgets and create alerts based on selection.
    // We wipe all existing alerts for each item first to handle onboarding
    // replays where the user may have changed their mind.
    for (final item in _subscriptions) {
      final rid = item.recurringId;
      if (rid == null) continue;

      final emoji = _getEmoji(item);

      // Remove any old alerts (recurring + cancel) so we start clean
      await AlertRepository.deleteAllAlertsByRecurringId(rid);

      if (_selectedIds.contains(rid)) {
        final weeklyLimit = _parseAmount(_amountCtrls[rid]?.text ?? '');
        if (weeklyLimit <= 0) continue;

        final customName = _nameOverrides[rid];
        final budget = BudgetModel(
          categoryId: item.categoryId,
          recurringTransactionId: rid,
          label: customName,
          weeklyLimit: weeklyLimit,
          periodStart: periodStart,
        );
        await BudgetRepository.insertOrUpdateRecurring(budget);

        final displayTitle = _displayName(item);
        await AlertRepository.upsertRecurringAlert(
          recurringId: rid,
          title: displayTitle,
          message: 'Due soon for \$${item.amount.toStringAsFixed(2)}',
          icon: emoji,
          leadTimeDays: 3,
        );
      } else {
        await BudgetRepository.deleteByRecurringId(rid);

        final displayTitle = _displayName(item);
        await AlertRepository.insertCancelSubscription(
          recurringId: rid,
          title: 'Cancel $displayTitle',
          icon: emoji,
          amount: item.amount,
        );
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
            widget.editMode ? 'Edit recurring payments' : 'Recurring payments'),
      ),
      body: _loading
          ? _buildLoadingState()
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

  Widget _buildLoadingState() {
    return Column(
      children: [
        const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6934).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync,
                      size: 36,
                      color: Color(0xFFFF6934),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _waitingForSync
                        ? 'Pulling your transactions…'
                        : 'Analysing your spending…',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _waitingForSync
                        ? 'Hang tight — we\'re fetching your bank data so Moni can find your recurring payments.'
                        : 'Identifying recurring payments from your transactions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_syncFailed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                child: const Text('Skip to dashboard'),
              ),
            ),
          ),
      ],
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
                'per week in recurring payments',
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
                _syncFailed ? Icons.cloud_off : Icons.autorenew,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _syncFailed
                  ? 'Couldn\'t pull transactions'
                  : 'No recurring payments found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _syncFailed
                  ? 'We had trouble fetching your bank data. You can continue to the dashboard and try again later.'
                  : "We didn't detect any recurring payments yet. You can add them later as more transactions come in.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            if (_syncFailed) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Go to dashboard'),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
            ],
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
            'Select the detected recurring payments you would like to create budgets for. Reminders will be created to cancel unselected recurring payments.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
        ),

        Text(
          'Hold to edit',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 8),

        // Subscription cards
        for (final sub in _subscriptions)
          _buildSubscriptionTile(sub),
      ],
    );
  }

  String _displayName(_SubscriptionItem item) {
    final rid = item.recurringId;
    if (rid != null && _nameOverrides.containsKey(rid)) {
      return _nameOverrides[rid]!;
    }
    return item.transactionName ?? item.label;
  }

  Widget _buildSubscriptionTile(_SubscriptionItem item) {
    final rid = item.recurringId;
    if (rid == null) return const SizedBox.shrink();

    final isSelected = _selectedIds.contains(rid);
    final emoji = _getEmoji(item);
    final name = _displayName(item);

    final isMonthly = item.frequency == 'monthly';
    final weeklyAmount = _parseAmount(_amountCtrls[rid]?.text ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSelection(rid, !isSelected),
        onLongPress: () => _editSubscription(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? BuxlyColors.teal.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? BuxlyColors.teal.withOpacity(0.4)
                  : Colors.black12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMonthly) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BuxlyColors.teal.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${item.amount.toStringAsFixed(0)}/mo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? BuxlyColors.darkText.withOpacity(0.6)
                          : Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? BuxlyColors.teal.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${weeklyAmount.toStringAsFixed(0)}/wk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? BuxlyColors.darkText
                        : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? BuxlyColors.teal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    width: 2,
                    color: isSelected
                        ? BuxlyColors.teal
                        : Colors.black26,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
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

  Future<void> _editSubscription(_SubscriptionItem item) async {
    final rid = item.recurringId;
    if (rid == null) return;

    final amountCtrl = _amountCtrls[rid];
    if (amountCtrl == null) return;

    final currentName = _displayName(item);
    final result = await showModalBottomSheet<_SubscriptionEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SubscriptionEditorSheet(
        initialName: currentName,
        initialAmount: amountCtrl.text,
        helperText: item.frequency == 'monthly'
            ? 'Original: \$${item.amount.toStringAsFixed(2)}/month'
            : 'Original: \$${item.amount.toStringAsFixed(2)}/week',
      ),
    );

    if (result != null) {
      setState(() {
        amountCtrl.text = _parseAmount(result.amount).toStringAsFixed(2);
        final trimmedName = result.name.trim();
        final defaultName = item.transactionName ?? item.label;
        if (trimmedName.isNotEmpty && trimmedName != defaultName) {
          _nameOverrides[rid] = trimmedName;
        } else {
          _nameOverrides.remove(rid);
        }
      });
    }
  }

  String _getEmoji(_SubscriptionItem item) {
    return _emojiHelper?.emojiForName(item.label) ??
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

class _SubscriptionEditResult {
  final String name;
  final String amount;
  const _SubscriptionEditResult({required this.name, required this.amount});
}

class _SubscriptionEditorSheet extends StatefulWidget {
  final String initialName;
  final String initialAmount;
  final String? helperText;

  const _SubscriptionEditorSheet({
    required this.initialName,
    required this.initialAmount,
    this.helperText,
  });

  @override
  State<_SubscriptionEditorSheet> createState() =>
      _SubscriptionEditorSheetState();
}

class _SubscriptionEditorSheetState extends State<_SubscriptionEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _amountCtrl = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
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
          const Text(
            'Edit recurring payment',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
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
                onPressed: () => Navigator.pop(
                  context,
                  _SubscriptionEditResult(
                    name: _nameCtrl.text.trim(),
                    amount: _amountCtrl.text.trim(),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
