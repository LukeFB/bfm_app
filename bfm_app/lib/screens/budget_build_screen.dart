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
  const BudgetBuildScreen({super.key});

  @override
  State<BudgetBuildScreen> createState() => _BudgetBuildScreenState();
}

class _BudgetBuildScreenState extends State<BudgetBuildScreen> {
  bool _loading = true;
  List<BudgetSuggestionModel> _suggestions = [];
  final Map<int?, bool> _selected = {}; // by categoryId (null allowed for map keys)
  final Map<int?, TextEditingController> _amountCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final list = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );

    // Start deselected; prefill text fields
    for (final s in list.where((x) => !x.isUncategorizedGroup)) {
      _selected[s.categoryId] = false;
      _amountCtrls[s.categoryId]?.dispose();
      _amountCtrls[s.categoryId] =
          TextEditingController(text: _roundTo(s.weeklySuggested, 1).toStringAsFixed(2));
    }

    setState(() {
      _suggestions = list;
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
            _roundTo(s.weeklySuggested, 1).toStringAsFixed(2);
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
          text: _roundTo(s.weeklySuggested, 1).toStringAsFixed(2),
        );
        bool addToBudget = true;
        bool creating = false;
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
                                onSubmitted: (_) => _createCategory(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: creating ? null : _createCategory,
                              child: creating
                                  ? const SizedBox(
                                      width: 16, height: 16,
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
                              icon: const Icon(Icons.done),
                              onPressed: (chosenId == null)
                                  ? null
                                  : () {
                                      Navigator.pop(ctx, {
                                        'categoryId': chosenId,
                                        'categoryName': chosenName ?? 'Category',
                                        'add': addToBudget,
                                        'amount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                                      });
                                    },
                              label: const Text('Assign'),
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
      if (!_amountCtrls.containsKey(catId)) {
        // If the category doesn't show up due to filtering, inject a lightweight row
        _amountCtrls[catId] = TextEditingController(text: weeklyAmount.toStringAsFixed(2));
        _selected[catId] = true;

        setState(() {
          _suggestions.insert(
            0,
            BudgetSuggestionModel(
              categoryId: catId,
              categoryName: catName,
              weeklySuggested: weeklyAmount,
              usageCount: 0,
              txCount: 0,
              hasRecurring: false,
              isUncategorizedGroup: false,
            ),
          );
        });
      } else {
        setState(() {
          _selected[catId] = true;
          _amountCtrls[catId]!.text = weeklyAmount.toStringAsFixed(2);
        });
      }
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
        title: const Text('Build Your Weekly Budget'),
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
                      const Text(
                        'Uncategorized items are shown first. Ordered by recurring, popularity, and weekly spend. Small items (< \$5/wk) are hidden.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
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
                    ],
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

                      if (isGroup) {
                        // --- "uncategorized-by-description" row (with Categorize) ---
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                s.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
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
                          ],
                        );
                      }

                      final selected = _selected[s.categoryId] ?? false;
                      final ctrl = _amountCtrls[s.categoryId]!;

                      return Column(
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
                                if (s.hasRecurring)
                                  const _Pill(label: 'Recurring', icon: Icons.repeat),
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
                                      signed: false, decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Weekly limit',
                                      prefixText: '\$',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}), // update Selected total live
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StepperButtons(
                                  enabled: selected,
                                  onMinus: () {
                                    final v = _parseAmount(ctrl.text);
                                    final n = _roundTo((v - 1.0).clamp(0.0, double.infinity), 1);
                                    setState(() => ctrl.text = n.toStringAsFixed(2));
                                  },
                                  onPlus: () {
                                    final v = _parseAmount(ctrl.text);
                                    final n = _roundTo(v + 1.0, 1);
                                    setState(() => ctrl.text = n.toStringAsFixed(2));
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
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
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _Pill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.green.shade300),
        color: Colors.green.shade50,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.green.shade700),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
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
