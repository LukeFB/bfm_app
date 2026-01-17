/// ---------------------------------------------------------------------------
/// File: lib/screens/budget_build_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/budget/build` after bank connect and `/budget/edit` from settings.
///
/// Purpose:
///   - Post-bank-connection screen where a user builds their weekly budget from
///     data-driven suggestions. Categories are ordered by detected recurring,
///     then category usage, then weekly spend. Users can toggle categories,
///     edit weekly limits, categorise uncategorized descriptions, and save.
///
/// Inputs:
///   - Suggestions from `BudgetAnalysisService`, existing budgets (edit mode),
///     category rows, and uncategorized transaction clusters.
///
/// Outputs:
///   - Writes selected categories into the `budgets` table and optionally
///     re-categorises transactions the user tags.
///
/// UX notes:
///   - Starts with all items deselected.
///   - Excludes categories < $5/week by default (recurring are kept).
///   - "Uncategorized" is split by description and can be categorised inline.
///   - After Save, navigates straight to Dashboard.
///   - Users can create a NEW category while categorising an uncategorized row,
///     and optionally add it to the budget immediately with a custom weekly amount.
/// ---------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/models/budget_suggestion_model.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/screens/budget_recurring_screen.dart';

/// Main UI for selecting suggested categories and setting weekly limits.
class BudgetBuildScreen extends StatefulWidget {
  const BudgetBuildScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<BudgetBuildScreen> createState() => _BudgetBuildScreenState();
}

/// Holds suggestion state, selection toggles, and text controllers.
class _BudgetBuildScreenState extends State<BudgetBuildScreen> {
  bool _loading = true;
  List<BudgetSuggestionModel> _suggestions = [];
  List<BudgetSuggestionModel> _baseSuggestions = [];
  final Map<int, BudgetSuggestionModel> _manualSuggestions = {};
  final Map<int?, bool> _selected = {}; // by categoryId (null allowed for map keys)
  final Map<int?, TextEditingController> _amountCtrls = {};
  List<_RecurringBudgetItem> _recurringItems = [];
  Map<int, BudgetModel> _existingBudgetMap = {};

  static const double _kWeeksPerMonth = 4.345; // convert monthly -> weekly

  List<BudgetSuggestionModel> _composeSuggestionsList() => [
        ..._manualSuggestions.values,
        ..._baseSuggestions,
      ];

  /// Kicks off the first suggestion load when the widget mounts.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Refreshes analysis suggestions, merges existing budgets (in edit mode),
  /// restores user selection state, and wires controllers for every row.
  Future<void> _load() async {
    final previousSelection = Map<int?, bool>.from(_selected);
    final previousAmounts = <int?, String>{
      for (final entry in _amountCtrls.entries) entry.key: entry.value.text,
    };
    setState(() => _loading = true);

    await BudgetAnalysisService.identifyRecurringTransactions();

    final list = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );
    final recurringItems = await _fetchRecurringBudgetItems();

    Map<int, BudgetModel> existingBudgets = {};
    Map<int, String> existingBudgetNames = {};
    if (widget.editMode) {
      final budgets = await BudgetRepository.getAll();
      existingBudgets = {
        for (final b in budgets.where((b) => b.categoryId != null))
          b.categoryId!: b,
      };
      if (existingBudgets.isNotEmpty) {
        existingBudgetNames =
            await CategoryRepository.getNamesByIds(existingBudgets.keys);
      }
    }

    if (!mounted) return;

    final nextSelected = <int?, bool>{};
    final nextControllers = <int?, TextEditingController>{};
    final remainingManual = Map<int, BudgetSuggestionModel>.from(_manualSuggestions);

    for (final s in list.where((x) => !x.isUncategorizedGroup)) {
      final id = s.categoryId;
      if (id == null) continue;

      remainingManual.remove(id);

      final existingCtrl = _amountCtrls[id];
      nextControllers[id] = existingCtrl ??
          TextEditingController(
            text: s.weeklySuggested.toStringAsFixed(2),
          );

      final previousAmount = previousAmounts[id];
      if (previousAmount != null) {
        nextControllers[id]!.text = previousAmount;
      } else {
        final budgetPrefill = existingBudgets[id];
        if (budgetPrefill != null) {
          nextControllers[id]!.text = budgetPrefill.weeklyLimit.toStringAsFixed(2);
        }
      }

      if (previousSelection.containsKey(id)) {
        nextSelected[id] = previousSelection[id] ?? false;
      } else {
        nextSelected[id] = existingBudgets.containsKey(id);
      }
    }

    if (widget.editMode && existingBudgets.isNotEmpty) {
      final manualBudgetEntries = <int, BudgetSuggestionModel>{};
      for (final entry in existingBudgets.entries) {
        final id = entry.key;
        if (list.any((x) => x.categoryId == id)) continue;
        manualBudgetEntries[id] = BudgetSuggestionModel(
          categoryId: id,
          categoryName: existingBudgetNames[id] ?? 'Budget',
          weeklySuggested: entry.value.weeklyLimit,
          usageCount: 0,
          txCount: 0,
          hasRecurring: false,
        );
      }
      remainingManual.addAll(manualBudgetEntries);
    }

    for (final entry in remainingManual.entries) {
      final id = entry.key;
      final model = entry.value;
      final existingCtrl = _amountCtrls[id];
      final defaultText =
          previousAmounts[id] ?? model.weeklySuggested.toStringAsFixed(2);
      nextControllers[id] = existingCtrl ?? TextEditingController(text: defaultText);
      final previousAmount = previousAmounts[id];
      if (previousAmount != null) {
        nextControllers[id]!.text = previousAmount;
      }
      nextSelected[id] = previousSelection[id] ?? true;
    }

    for (final entry in _amountCtrls.entries) {
      if (!nextControllers.containsKey(entry.key)) {
        entry.value.dispose();
      }
    }

    _amountCtrls
      ..clear()
      ..addAll(nextControllers);
    _selected
      ..clear()
      ..addAll(nextSelected);
    _manualSuggestions
      ..clear()
      ..addAll(remainingManual);

    setState(() {
      _baseSuggestions = list;
      _suggestions = _composeSuggestionsList();
      _recurringItems = recurringItems;
      _existingBudgetMap = widget.editMode ? existingBudgets : {};
      _loading = false;
    });
  }

  /// Cleans up text controllers to avoid leaks.
  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Returns the current week's Monday in YYYY-MM-DD for budget period start.
  String _mondayOfThisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  /// Parses a text field value into a non-negative double.
  double _parseAmount(String s) {
    final v = double.tryParse(s.trim());
    if (v == null || v.isNaN || v.isInfinite) return 0.0;
    return max(0.0, v);
  }

  /// Rounds a value to the nearest `step`. Used for +/- buttons.
  double _roundTo(double x, double step) => (step <= 0) ? x : (x / step).round() * step;

  /// Persists every selected category as a budget row (clearing old ones when
  /// in edit mode) and routes back to the dashboard.
  Future<void> _saveSelected() async {
    final periodStart = _mondayOfThisWeek();
    int saved = 0;

    if (widget.editMode) {
      await BudgetRepository.clearAll();
    }

    for (final s in _suggestions) {
      if (s.isUncategorizedGroup) continue; // not selectable as budgets
      final selected = _selected[s.categoryId] ?? false;
      if (!selected || s.categoryId == null) continue;

      final ctrl = _amountCtrls[s.categoryId]!;
      final weeklyLimit = _parseAmount(ctrl.text);
      if (weeklyLimit <= 0) continue;

      final m = BudgetModel(
        categoryId: s.categoryId!,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );

      await BudgetRepository.insert(m);
      saved += 1;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $saved budget${saved == 1 ? '' : 's'}')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BudgetRecurringScreen()),
    );
  }

  /// Same normalisation as the service (local to avoid importing a private fn)
  String _normalizeText(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Categorize an "uncategorized-by-description" suggestion:
  /// - Choose existing OR create new category.
  /// - Optionally add to budget with custom weekly amount.
  Future<void> _categorizeUncatGroup(BudgetSuggestionModel s) async {
    // Preload categories for list
    final cats = await CategoryRepository.getAllOrderedByUsage();

    if (!mounted) return;

    // Result payload from the modal
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        int? chosenId;
        String? chosenName;
        bool assigning = false;
        final newCatCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> _createCategory() async {
              final name = newCatCtrl.text.trim();
              if (name.isEmpty) return;
              final id = await CategoryRepository.ensureByName(name);
              chosenId = id;
              chosenName = name;
              setModalState(() {});
            }

            void _pick(Map<String, dynamic> c) {
              chosenId = c['id'] as int;
              chosenName = (c['name'] as String?) ?? 'Category';
              setModalState(() {}); // refresh checkmark
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.8,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Assign a Category',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      const Divider(height: 1),

                      // Existing categories
                      Expanded(
                        child: ListView.separated(
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = cats[i];
                            final selected = chosenId == c['id'];
                            return ListTile(
                              title: Text(c['name'] as String),
                              trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
                              onTap: () => _pick(c),
                            );
                          },
                        ),
                      ),

                      // Create new category
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: TextField(
                          controller: newCatCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Create new category',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                          onSubmitted: (_) => _createCategory(),
                        ),
                      ),

                      // Budget inline
                      // Confirm
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            const Spacer(),
                            FilledButton.icon(
                              icon: assigning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.done),
                              onPressed: (!assigning &&
                                      (chosenId != null ||
                                          newCatCtrl.text.trim().isNotEmpty))
                                  ? () async {
                                      if (chosenId == null) {
                                        final name = newCatCtrl.text.trim();
                                        if (name.isEmpty) return;
                                        setModalState(() => assigning = true);
                                        final id = await CategoryRepository.ensureByName(name);
                                        chosenId = id;
                                        chosenName = name;
                                        setModalState(() => assigning = false);
                                      }

                                      Navigator.pop(ctx, {
                                        'categoryId': chosenId,
                                        'categoryName': chosenName ?? 'Category',
                                      });
                                    }
                                  : null,
                              label: Text(assigning ? 'Assigning...' : 'Assign'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final int catId = result['categoryId'] as int;
    final String catName = (result['categoryName'] as String?) ?? 'Category';

    // Re-tag uncategorized rows by normalized description key
    final key = _normalizeText(s.description ?? s.categoryName);
    await TransactionRepository.updateUncategorizedByDescriptionKey(key, catId);

    // Refresh suggestions from DB
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categorised “${s.categoryName}” → $catName')),
    );
  }

  Future<List<_RecurringBudgetItem>> _fetchRecurringBudgetItems() async {
    final allRecurring = await RecurringRepository.getAll();
    final expenses = allRecurring
        .where((r) => r.transactionType.toLowerCase() == 'expense')
        .toList();
    final filtered = expenses
        .where((r) {
          final freq = r.frequency.toLowerCase();
          return freq == 'weekly' || freq == 'monthly';
        })
        .toList();
    if (filtered.isEmpty) return const [];

    final names = await CategoryRepository.getNamesByIds(
      filtered.map((r) => r.categoryId),
    );

    final items = filtered.map((r) {
      final freq = r.frequency.toLowerCase();
      final weeklyAmount =
          freq == 'weekly' ? r.amount : r.amount / _kWeeksPerMonth;
      final fallback = (r.description ?? '').trim();
      final label = names[r.categoryId] ??
          (fallback.isEmpty ? 'Recurring expense' : fallback);
      return _RecurringBudgetItem(
        recurringId: r.id,
        categoryId: r.categoryId,
        label: label,
        frequency: freq,
        amount: r.amount,
        weeklyAmount: double.parse(weeklyAmount.toStringAsFixed(2)),
      );
    }).toList();

    items.sort((a, b) {
      if (a.frequency != b.frequency) {
        return a.frequency == 'weekly' ? -1 : 1;
      }
      return b.weeklyAmount.compareTo(a.weeklyAmount);
    });

    return items;
  }

  void _addRecurringBudget(_RecurringBudgetItem item) {
    final int catId = item.categoryId;
    final weeklyText = item.weeklyAmount.toStringAsFixed(2);

    if (!_amountCtrls.containsKey(catId)) {
      final controller = TextEditingController(text: weeklyText);
      _amountCtrls[catId] = controller;
      _manualSuggestions[catId] = BudgetSuggestionModel(
        categoryId: catId,
        categoryName: item.label,
        weeklySuggested: item.weeklyAmount,
        usageCount: 0,
        txCount: 0,
        hasRecurring: true,
      );
    } else {
      _amountCtrls[catId]!.text = weeklyText;
    }

    _selected[catId] = true;

    setState(() {
      _suggestions = _composeSuggestionsList();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${item.label} at \$${weeklyText}/week')),
      );
    }
  }

  /// Builds the entire budget builder UI: headers, suggestions list, and footer.
  @override
  Widget build(BuildContext context) {
    final uncatSuggestions = _uncategorizedSuggestions();
    final categorySuggestions = _categorySuggestions();
    final existingBudgetSuggestions = _existingBudgetSuggestions();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? 'Review & Edit Budget' : 'Build Your Weekly Budget'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.editMode
                          ? 'Existing budget categories are pre-selected. Adjust the weekly amounts below.'
                          : 'We detected your average weekly expenses over the last 4 months and suggested budgets below. Select everything that applies.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (existingBudgetSuggestions.isNotEmpty)
                        _buildExistingBudgetsCard(existingBudgetSuggestions),
                      if (uncatSuggestions.isNotEmpty)
                        _buildUncategorizedExpansion(uncatSuggestions),
                      if (_recurringItems.isNotEmpty)
                        _buildRecurringExpansion(_recurringItems),
                      if (categorySuggestions.isNotEmpty)
                        _buildCategoryExpansion(categorySuggestions),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: const Border(top: BorderSide(width: 0.5, color: Colors.black12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _SelectedTotalBadge(amount: _selectedTotal()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          onPressed: _saveSelected,
                          label: const Text('Save & Continue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<BudgetSuggestionModel> _uncategorizedSuggestions() {
    final list = _suggestions.where((s) => s.isUncategorizedGroup).toList();
    list.sort((a, b) => b.txCount.compareTo(a.txCount));
    return list;
  }

  List<BudgetSuggestionModel> _categorySuggestions() {
    final base =
        _suggestions.where((s) => !s.isUncategorizedGroup).toList(growable: false);
    if (!widget.editMode || _existingBudgetMap.isEmpty) {
      return base;
    }
    final existingIds = _existingBudgetMap.keys.toSet();
    return base
        .where((s) => s.categoryId == null || !existingIds.contains(s.categoryId))
        .toList(growable: false);
  }

  List<BudgetSuggestionModel> _existingBudgetSuggestions() {
    if (!widget.editMode || _existingBudgetMap.isEmpty) return const [];
    final existingIds = _existingBudgetMap.keys.toSet();
    final list = _suggestions
        .where((s) => !s.isUncategorizedGroup && existingIds.contains(s.categoryId))
        .toList();
    list.sort((a, b) => a.categoryName.compareTo(b.categoryName));
    return list;
  }

  Widget _buildExistingBudgetsCard(List<BudgetSuggestionModel> items) {
    final maxHeight = min(items.length * 130.0, 420.0);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Current budgets'),
          subtitle: const Text(
            'Edit saved categories below. Uncheck to remove from your plan.',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            SizedBox(
              height: maxHeight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = _buildCategoryRow(items[index]);
                  return Column(
                    children: [
                      row,
                      if (index != items.length - 1) const Divider(height: 1),
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

  Widget _buildUncategorizedExpansion(List<BudgetSuggestionModel> items) {
    final maxHeight = min(items.length * 76.0, 320.0);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.error_outline),
          title: const Text('Needs categorization'),
          subtitle: const Text(
            'Match transactions to categories to tidy things up.',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            SizedBox(
              height: maxHeight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = _buildUncategorizedRow(items[index]);
                  return Column(
                    children: [
                      row,
                      if (index != items.length - 1) const Divider(height: 1),
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

  Widget _buildRecurringExpansion(List<_RecurringBudgetItem> items) {
    final maxHeight = min(items.length * 118.0, 360.0);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.autorenew),
          title: const Text('Recurring payments'),
          subtitle: const Text(
            'Turn detected weekly/monthly bills into a budget line.',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            SizedBox(
              height: maxHeight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = _buildRecurringRow(items[index]);
                  return Column(
                    children: [
                      row,
                      if (index != items.length - 1) const Divider(height: 1),
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

  Widget _buildRecurringRow(_RecurringBudgetItem item) {
    final alreadyAdded = _selected[item.categoryId] ?? false;
    final weeklyText = item.weeklyAmount.toStringAsFixed(2);
    final paymentLabel = item.frequency == 'monthly'
        ? 'Monthly payment: \$${item.amount.toStringAsFixed(2)}'
        : 'Weekly payment: \$${item.amount.toStringAsFixed(2)}';
    final weeklyLine = item.frequency == 'monthly'
        ? 'Budget weekly limit: ≈ \$${weeklyText}'
        : 'Budget weekly limit: \$${weeklyText}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        item.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$paymentLabel • ${item.frequencyLabel}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              weeklyLine,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      trailing: FilledButton.icon(
        icon: alreadyAdded ? const Icon(Icons.check) : const Icon(Icons.add),
        onPressed: alreadyAdded ? null : () => _addRecurringBudget(item),
        label: Text(alreadyAdded ? 'Added' : 'Add to budget'),
      ),
    );
  }

  Widget _buildCategoryExpansion(List<BudgetSuggestionModel> items) {
    final maxHeight = min(items.length * 130.0, 420.0);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.checklist_outlined),
          title: Text(widget.editMode ? 'Suggested updates' : 'Suggested categories'),
          subtitle: Text(
            widget.editMode
                ? 'New categories you can add to your weekly plan.'
                : 'Toggle the items you want to track weekly.',
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            SizedBox(
              height: maxHeight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = _buildCategoryRow(items[index]);
                  return Column(
                    children: [
                      row,
                      if (index != items.length - 1) const Divider(height: 1),
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

  Widget _buildUncategorizedRow(BudgetSuggestionModel s) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        s.categoryName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.orange,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Weekly suggested: \$${s.weeklySuggested.toStringAsFixed(2)} • tx: ${s.txCount}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.category_outlined),
        label: const Text('Categorize'),
        onPressed: () => _categorizeUncatGroup(s),
      ),
    );
  }

  Widget _buildCategoryRow(BudgetSuggestionModel s) {
    final selected = _selected[s.categoryId] ?? false;
    final ctrl = _amountCtrls[s.categoryId]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Checkbox(
              value: selected,
              onChanged: (v) => setState(() => _selected[s.categoryId] = v ?? false),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    s.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Weekly suggested: \$${s.weeklySuggested.toStringAsFixed(2)} • usage: ${s.usageCount} • tx: ${s.txCount}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    enabled: selected,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weekly limit',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                _StepperButtons(
                  enabled: selected,
                  onMinus: () {
                    final v = _parseAmount(ctrl.text);
                    final rounded = _roundTo(v, 1);
                    final next = max(0.0, rounded - 1.0);
                    setState(() => ctrl.text = next.toStringAsFixed(2));
                  },
                  onPlus: () {
                    final v = _parseAmount(ctrl.text);
                    final rounded = _roundTo(v, 1);
                    final next = rounded + 1.0;
                    setState(() => ctrl.text = next.toStringAsFixed(2));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the running total for selected categories so the footer badge can
  /// display a weekly sum.
  double _selectedTotal() {
    double sum = 0;
    for (final s in _suggestions) {
      if (s.isUncategorizedGroup) continue;
      if (_selected[s.categoryId] ?? false) {
        sum += _parseAmount(_amountCtrls[s.categoryId]!.text);
      }
    }
    return sum;
  }

}
/// +/- buttons that nudge the weekly amount by \$1 increments.
class _StepperButtons extends StatelessWidget {
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _StepperButtons({required this.enabled, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: enabled ? onMinus : null),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: enabled ? onPlus : null),
      ],
    );
  }
}

/// Shows the aggregate weekly total selected so far.
class _SelectedTotalBadge extends StatelessWidget {
  final double amount;
  const _SelectedTotalBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: FittedBox(child: Text('Selected: \$${amount.toStringAsFixed(2)}/wk')),
    );
  }
}

/// Lightweight view-model for recurring expenses surfaced in the builder.
class _RecurringBudgetItem {
  final int? recurringId;
  final int categoryId;
  final String label;
  final String frequency;
  final double amount;
  final double weeklyAmount;

  const _RecurringBudgetItem({
    required this.recurringId,
    required this.categoryId,
    required this.label,
    required this.frequency,
    required this.amount,
    required this.weeklyAmount,
  });

  String get frequencyLabel =>
      frequency == 'monthly' ? 'Monthly' : 'Weekly';
}
