/// ---------------------------------------------------------------------------
/// File: budget_build_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Post-bank-connection screen where a user builds their weekly budget from
///   data-driven suggestions. Categories are ordered by detected recurring,
///   then category usage, then weekly spend. Users can toggle categories,
///   edit weekly limits, and save.
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
import 'package:bfm_app/repositories/transaction_repository.dart';

class BudgetBuildScreen extends StatefulWidget {
  const BudgetBuildScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<BudgetBuildScreen> createState() => _BudgetBuildScreenState();
}

class _BudgetBuildScreenState extends State<BudgetBuildScreen> {
  bool _loading = true;
  List<BudgetSuggestionModel> _suggestions = [];
  List<BudgetSuggestionModel> _baseSuggestions = [];
  final Map<int, BudgetSuggestionModel> _manualSuggestions = {};
  final Map<int?, bool> _selected = {}; // by categoryId (null allowed for map keys)
  final Map<int?, TextEditingController> _amountCtrls = {};
  Set<int> _existingBudgetCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final previousSelection = Map<int?, bool>.from(_selected);
    final previousAmounts = <int?, String>{
      for (final entry in _amountCtrls.entries) entry.key: entry.value.text,
    };
    setState(() => _loading = true);

    final list = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );

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
      _existingBudgetCategoryIds =
          widget.editMode ? existingBudgets.keys.toSet() : {};
      _baseSuggestions = list;
      _suggestions = [
        ..._manualSuggestions.values,
        ..._baseSuggestions,
      ];
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
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

  double _roundTo(double x, double step) => (step <= 0) ? x : (x / step).round() * step;

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
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
  }

  void _selectAllRecurring() {
    setState(() {
      for (final s in _suggestions.where((x) => !x.isUncategorizedGroup && x.hasRecurring)) {
        _selected[s.categoryId] = true;
        _amountCtrls[s.categoryId]?.text =
            s.weeklySuggested.toStringAsFixed(2);
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final s in _suggestions.where((x) => !x.isUncategorizedGroup)) {
        _selected[s.categoryId] = false;
      }
    });
  }

  // Same normalisation as the service (local to avoid importing a private fn)
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
        final amountCtrl = TextEditingController(
          text: s.weeklySuggested.toStringAsFixed(2),
        );
        bool addToBudget = true;
        bool creating = false;
        bool assigning = false;
        final newCatCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> _createCategory() async {
              final name = newCatCtrl.text.trim();
              if (name.isEmpty) return;
              setModalState(() => creating = true);
              final id = await CategoryRepository.ensureByName(name);
              chosenId = id;
              chosenName = name;
              setModalState(() => creating = false);
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
                        child: Row(
                          children: [
                            Expanded(
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
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: creating ? null : _createCategory,
                              child: creating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Create'),
                            ),
                          ],
                        ),
                      ),

                      // Budget inline
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                  signed: false, decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Add to weekly budget as',
                                  prefixText: '\$',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Add now', style: TextStyle(fontSize: 12)),
                                Switch(
                                  value: addToBudget,
                                  onChanged: (v) => setModalState(() => addToBudget = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

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
                                        'add': addToBudget,
                                        'amount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
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
    final bool addToBudget = (result['add'] as bool?) ?? false;
    final double weeklyAmount = (result['amount'] as num?)?.toDouble() ?? 0.0;

    // Re-tag uncategorized rows by normalized description key
    final key = _normalizeText(s.description ?? s.categoryName);
    await TransactionRepository.updateUncategorizedByDescriptionKey(key, catId);

    // Refresh suggestions from DB
    await _load();

    // If user chose to add immediately, pre-select and set amount
    if (addToBudget) {
      final ctrl = _amountCtrls.putIfAbsent(
        catId,
        () => TextEditingController(text: weeklyAmount.toStringAsFixed(2)),
      );
      ctrl.text = weeklyAmount.toStringAsFixed(2);
      _selected[catId] = true;

      final existsInBase =
          _baseSuggestions.any((element) => element.categoryId == catId);
      if (!existsInBase) {
        _manualSuggestions[catId] = BudgetSuggestionModel(
          categoryId: catId,
          categoryName: catName,
          weeklySuggested: weeklyAmount,
          usageCount: 0,
          txCount: 0,
          hasRecurring: false,
          isUncategorizedGroup: false,
        );
      }

      _refreshDisplayedSuggestions();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categorised “${s.categoryName}” → $catName')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                // Header summary (responsive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.editMode
                            ? 'Existing budget categories are pre-selected. Look for the “New” tag to spot fresh suggestions.'
                            : 'Uncategorized items are shown first. Ordered by recurring, popularity, and weekly spend. Small items (< \$5/wk) are hidden.',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.auto_awesome),
                            onPressed: _selectAllRecurring,
                            label: const Text('Select Recurring'),
                          ),
                          OutlinedButton(
                            onPressed: _clearAll,
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(
                        selectedCount: _selectedCount(),
                        total: _selectedTotal(),
                        editing: widget.editMode,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Card(
                    child: ListTile(
                      title: const Text('Savings goals'),
                      subtitle: const Text(
                        'Weekly contributions live on the Goals screen.',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/goals');
                          if (!mounted) return;
                          await _load();
                        },
                        child: const Text('Open goals'),
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Suggestions list
                Expanded(
                  child: ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, i) {
                      final s = _suggestions[i];
                      final bool isGroup = s.isUncategorizedGroup;
                      final bool showGroupHeader =
                          isGroup && (i == 0 || !_suggestions[i - 1].isUncategorizedGroup);
                      final bool showCategoryHeader =
                          !isGroup && (i == 0 || _suggestions[i - 1].isUncategorizedGroup);

                      final children = <Widget>[
                        if (showGroupHeader)
                          const _SectionHeader(
                            icon: Icons.error_outline,
                            label: 'Needs categorization',
                            description: 'Match transactions to categories to tidy things up.',
                          ),
                        if (showCategoryHeader)
                          _SectionHeader(
                            icon: Icons.checklist_outlined,
                            label: widget.editMode ? 'Suggested updates' : 'Suggested categories',
                            description: widget.editMode
                                ? 'New categories you can add to your weekly plan.'
                                : 'Toggle the items you want to track weekly.',
                          ),
                      ];

                      if (isGroup) {
                        children.addAll([
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          ),
                          const Divider(height: 1),
                        ]);
                      } else {
                        final selected = _selected[s.categoryId] ?? false;
                        final ctrl = _amountCtrls[s.categoryId]!;
                        final bool isExistingBudget = s.categoryId != null &&
                            _existingBudgetCategoryIds.contains(s.categoryId);
                        final bool showNewBadge = widget.editMode && !isExistingBudget;

                        children.addAll([
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Checkbox(
                              value: selected,
                              onChanged: (v) =>
                                  setState(() => _selected[s.categoryId] = v ?? false),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.categoryName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (s.hasRecurring)
                                  const _Pill(label: 'Recurring', icon: Icons.repeat),
                                if (showNewBadge)
                                  const _Pill(
                                    label: 'New',
                                    icon: Icons.fiber_new,
                                    tint: Colors.orange,
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
                          const Divider(height: 1),
                        ]);
                      }

                      return Column(children: children);
                    },
                  ),
                ),

                // Save bar (no "Skip" – avoids overflow)
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

  void _refreshDisplayedSuggestions() {
    setState(() {
      _suggestions = [
        ..._manualSuggestions.values,
        ..._baseSuggestions,
      ];
    });
  }

  int _selectedCount() {
    var count = 0;
    for (final entry in _selected.entries) {
      if (entry.value) count += 1;
    }
    return count;
  }

}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? tint;
  const _Pill({required this.label, this.icon, this.tint});

  @override
  Widget build(BuildContext context) {
    final Color base = tint ?? Colors.green.shade700;
    final Color border = base.withOpacity(0.4);
    final Color background = base.withOpacity(0.12);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        color: background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: base),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: base)),
        ],
      ),
    );
  }
}

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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int selectedCount;
  final double total;
  final bool editing;

  const _SummaryCard({
    required this.selectedCount,
    required this.total,
    this.editing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selectedCount > 0;
    final title = hasSelection
        ? editing
            ? '$selectedCount budget${selectedCount == 1 ? '' : 's'} active'
            : '$selectedCount ${selectedCount == 1 ? 'category' : 'categories'} selected'
        : (editing ? 'No active budgets selected' : 'No categories selected yet');
    final subtitle = hasSelection
        ? 'Weekly total \$${total.toStringAsFixed(2)}'
        : (editing
            ? 'Toggle off categories to remove them from your plan.'
            : 'Pick a few categories to start planning.');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            hasSelection ? Icons.check_circle : Icons.lightbulb_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
