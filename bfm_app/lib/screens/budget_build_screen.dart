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
import 'package:bfm_app/utils/category_emoji_helper.dart';

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
  final Map<int?, bool> _selected =
      {}; // by categoryId (null allowed for map keys)
  final Map<int?, TextEditingController> _amountCtrls = {};
  List<_RecurringBudgetItem> _recurringItems = [];
  final Map<int, TextEditingController> _recurringAmountCtrls = {};
  final Set<int> _selectedRecurringIds = {};
  Map<int, _RecurringBudgetItem> _recurringItemLookup = {};
  late bool _recurringExpanded;
  final Set<String> _selectedUncatKeys = {};
  final Map<String, String> _uncatNameOverrides = {};
  final Map<String, String> _uncatAmountOverrides = {};
  CategoryEmojiHelper? _emojiHelper;

  static const double _kWeeksPerMonth = 4.345; // convert monthly -> weekly

  List<BudgetSuggestionModel> _composeSuggestionsList() => [
    ..._manualSuggestions.values,
    ..._baseSuggestions,
  ];

  /// Kicks off the first suggestion load when the widget mounts.
  @override
  void initState() {
    super.initState();
    _recurringExpanded = widget.editMode;
    _load();
  }

  /// Refreshes analysis suggestions, merges existing budgets (in edit mode),
  /// restores user selection state, and wires controllers for every row.
  Future<void> _load() async {
    final previousSelection = Map<int?, bool>.from(_selected);
    final previousAmounts = <int?, String>{
      for (final entry in _amountCtrls.entries) entry.key: entry.value.text,
    };
    final previousRecurringSelection = Set<int>.from(_selectedRecurringIds);
    final previousRecurringAmounts = <int, String>{
      for (final entry in _recurringAmountCtrls.entries)
        entry.key: entry.value.text,
    };
    final previousUncatSelection = Set<String>.from(_selectedUncatKeys);
    final previousUncatNames = Map<String, String>.from(_uncatNameOverrides);
    final previousUncatAmounts = Map<String, String>.from(_uncatAmountOverrides);
    setState(() => _loading = true);

    await BudgetAnalysisService.identifyRecurringTransactions();

    final list = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );
    final recurringItems = await _fetchRecurringBudgetItems();
    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();
    final recurringLookup = <int, _RecurringBudgetItem>{};
    for (final item in recurringItems) {
      final rid = item.recurringId;
      if (rid != null) {
        recurringLookup[rid] = item;
      }
    }
    final validRecurringIds = recurringLookup.keys.toSet();
    final sanitizedPreviousRecurring = previousRecurringSelection
        .where(validRecurringIds.contains)
        .toSet();

    Map<int, BudgetModel> existingBudgets = {};
    Map<int, String> existingBudgetNames = {};
    Map<String, BudgetModel> existingUncatBudgets = {};
    if (widget.editMode) {
      final budgets = await BudgetRepository.getAll();
      existingBudgets = {
        for (final b in budgets.where((b) => b.categoryId != null))
          b.categoryId!: b,
      };
      if (existingBudgets.isNotEmpty) {
        existingBudgetNames = await CategoryRepository.getNamesByIds(
          existingBudgets.keys,
        );
      }
      existingUncatBudgets = {
        for (final b in budgets)
          if ((b.uncategorizedKey?.trim().isNotEmpty ?? false))
            b.uncategorizedKey!.trim().toLowerCase(): b,
      };
    }

    final existingRecurringSelection = <int>{};
    final recurringBudgetPrefills = <int, String>{};
    if (widget.editMode && existingBudgets.isNotEmpty) {
      for (final item in recurringItems) {
        final rid = item.recurringId;
        if (rid == null) continue;
        final budget = existingBudgets[item.categoryId];
        if (budget == null) continue;
        existingRecurringSelection.add(rid);
        recurringBudgetPrefills[rid] = budget.weeklyLimit.toStringAsFixed(2);
      }
    }

    final allRecurringIds = Set<int>.from(validRecurringIds);
    final defaultRecurringSelection =
        widget.editMode ? existingRecurringSelection : allRecurringIds;
    final nextRecurringSelection = sanitizedPreviousRecurring.isNotEmpty
        ? sanitizedPreviousRecurring
        : defaultRecurringSelection;

    if (!mounted) return;

    final nextSelected = <int?, bool>{};
    final nextControllers = <int?, TextEditingController>{};
    final remainingManual = Map<int, BudgetSuggestionModel>.from(
      _manualSuggestions,
    );

    for (final s in list.where((x) => !x.isUncategorizedGroup)) {
      final id = s.categoryId;
      if (id == null) continue;

      remainingManual.remove(id);

      final existingCtrl = _amountCtrls[id];
      nextControllers[id] =
          existingCtrl ??
          TextEditingController(text: s.weeklySuggested.toStringAsFixed(2));

      final previousAmount = previousAmounts[id];
      if (previousAmount != null) {
        nextControllers[id]!.text = previousAmount;
      } else {
        final budgetPrefill = existingBudgets[id];
        if (budgetPrefill != null) {
          nextControllers[id]!.text = budgetPrefill.weeklyLimit.toStringAsFixed(
            2,
          );
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

    if (existingUncatBudgets.isNotEmpty) {
      final presentUncatKeys = list
          .where((s) => s.isUncategorizedGroup)
          .map(_uncatKey)
          .toSet();
      for (final entry in existingUncatBudgets.entries) {
        if (presentUncatKeys.contains(entry.key)) continue;
        final budget = entry.value;
        final displayName =
            (budget.label?.trim().isNotEmpty ?? false)
                ? budget.label!.trim()
                : (budget.uncategorizedKey ?? 'Budget');
        list.add(
          BudgetSuggestionModel(
            categoryId: null,
            categoryName: displayName,
            weeklySuggested: budget.weeklyLimit,
            usageCount: 0,
            txCount: 0,
            hasRecurring: false,
            isUncategorizedGroup: true,
            description: budget.uncategorizedKey ?? displayName,
          ),
        );
        presentUncatKeys.add(entry.key);
      }
    }

    for (final entry in remainingManual.entries) {
      final id = entry.key;
      final model = entry.value;
      final existingCtrl = _amountCtrls[id];
      final defaultText =
          previousAmounts[id] ?? model.weeklySuggested.toStringAsFixed(2);
      nextControllers[id] =
          existingCtrl ?? TextEditingController(text: defaultText);
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

    final uncatSuggestionLookup = <String, BudgetSuggestionModel>{};
    for (final suggestion in list.where((s) => s.isUncategorizedGroup)) {
      uncatSuggestionLookup[_uncatKey(suggestion)] = suggestion;
    }
    final nextUncatKeys = uncatSuggestionLookup.keys.toSet();

    final restoredSelectedUncat = previousUncatSelection
        .where(nextUncatKeys.contains)
        .toSet();
    final restoredNameOverrides = <String, String>{
      for (final entry in previousUncatNames.entries)
        if (nextUncatKeys.contains(entry.key)) entry.key: entry.value,
    };
    final restoredAmountOverrides = <String, String>{
      for (final entry in previousUncatAmounts.entries)
        if (nextUncatKeys.contains(entry.key)) entry.key: entry.value,
    };

    if (widget.editMode && existingUncatBudgets.isNotEmpty) {
      for (final entry in existingUncatBudgets.entries) {
        final key = entry.key;
        if (!nextUncatKeys.contains(key)) continue;
        final budget = entry.value;
        restoredSelectedUncat.add(key);
        final suggestion = uncatSuggestionLookup[key];
        final suggestionName = suggestion?.categoryName ?? '';
        final cleanedLabel = (budget.label ?? '').trim();
        if (cleanedLabel.isNotEmpty && cleanedLabel != suggestionName) {
          restoredNameOverrides[key] = cleanedLabel;
        } else if (cleanedLabel.isEmpty && suggestionName.isNotEmpty) {
          restoredNameOverrides.remove(key);
        }
        final amountText = budget.weeklyLimit.toStringAsFixed(2);
        final defaultAmount = suggestion?.weeklySuggested.toStringAsFixed(2);
        if (defaultAmount == null || defaultAmount != amountText) {
          restoredAmountOverrides[key] = amountText;
        } else {
          restoredAmountOverrides.remove(key);
        }
      }
    }

    setState(() {
      _baseSuggestions = list;
      _suggestions = _composeSuggestionsList();
      _recurringItems = recurringItems;
      _recurringItemLookup = recurringLookup;
      _selectedRecurringIds
        ..clear()
        ..addAll(nextRecurringSelection);
      _selectedUncatKeys
        ..clear()
        ..addAll(restoredSelectedUncat);
      _uncatNameOverrides
        ..clear()
        ..addAll(restoredNameOverrides);
      _uncatAmountOverrides
        ..clear()
        ..addAll(restoredAmountOverrides);
      _emojiHelper = emojiHelper;
      _loading = false;
    });

    _pruneUncatControllers(nextUncatKeys);
    _syncRecurringAmountControllers(
      recurringLookup,
      previousRecurringAmounts,
      recurringBudgetPrefills,
    );
  }

  /// Cleans up text controllers to avoid leaks.
  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    for (final c in _recurringAmountCtrls.values) {
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
  double _roundTo(double x, double step) =>
      (step <= 0) ? x : (x / step).round() * step;

  /// Persists every selected category as a budget row (clearing old ones when
  /// in edit mode) and routes back to the dashboard.
  Future<void> _saveSelected() async {
    final periodStart = _mondayOfThisWeek();
    int saved = 0;

    if (widget.editMode) {
      await BudgetRepository.clearAll();
    }

    for (final rid in _selectedRecurringIds) {
      final item = _recurringItemLookup[rid];
      if (item == null) continue;
      final weeklyLimit = _recurringAmountValue(rid, item);
      if (weeklyLimit <= 0) continue;
      final m = BudgetModel(
        categoryId: item.categoryId,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
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

    final uncatMap = {
      for (final s in _suggestions.where((s) => s.isUncategorizedGroup))
        _uncatKey(s): s,
    };

    for (final key in _selectedUncatKeys) {
      final suggestion = uncatMap[key];
      if (suggestion == null) continue;
      final targetName = _uncatResolvedName(key, suggestion);
      final weeklyLimit = _uncatAmountValue(key, suggestion);
      if (weeklyLimit <= 0) continue;
      final m = BudgetModel(
        categoryId: null,
        label: targetName,
        uncategorizedKey: key,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
    }

    if (!mounted) return;
    setState(() {
      _selectedRecurringIds.clear();
      _selectedUncatKeys.clear();
      _uncatNameOverrides.clear();
      _uncatAmountOverrides.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved $saved budget${saved == 1 ? '' : 's'}')),
    );
    if (widget.editMode) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/alerts/manage');
    }
  }

  Future<List<_RecurringBudgetItem>> _fetchRecurringBudgetItems() async {
    final allRecurring = await RecurringRepository.getAll();
    final expenses = allRecurring
        .where((r) => r.transactionType.toLowerCase() == 'expense')
        .toList();
    final filtered = expenses.where((r) {
      final freq = r.frequency.toLowerCase();
      return freq == 'weekly' || freq == 'monthly';
    }).toList();
    if (filtered.isEmpty) return const [];

    final names = await CategoryRepository.getNamesByIds(
      filtered.map((r) => r.categoryId),
    );

    final items = filtered.map((r) {
      final freq = r.frequency.toLowerCase();
      final weeklyAmount = freq == 'weekly'
          ? r.amount
          : r.amount / _kWeeksPerMonth;
      final description = (r.description ?? '').trim();
      final categoryLabel = (names[r.categoryId] ?? '').trim();
      final hasCategory =
          categoryLabel.isNotEmpty &&
          categoryLabel.toLowerCase() != 'uncategorized';
      final fallbackName = description.isNotEmpty
          ? description
          : 'Recurring expense';
      final label = hasCategory ? categoryLabel : fallbackName;
      final transactionName = hasCategory && description.isNotEmpty
          ? description
          : null;
      return _RecurringBudgetItem(
        recurringId: r.id,
        categoryId: r.categoryId,
        label: label,
        frequency: freq,
        amount: r.amount,
        weeklyAmount: double.parse(weeklyAmount.toStringAsFixed(2)),
        transactionName: transactionName,
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

  /// Builds the entire budget builder UI: headers, suggestions list, and footer.
  @override
  Widget build(BuildContext context) {
    final uncatSuggestions = _uncategorizedSuggestions();
    final categorySuggestions = _categorySuggestions();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editMode ? 'Review & Edit Budget' : 'Build Your Weekly Budget',
        ),
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
                          : 'Select the essential expenses you would like to budget for.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (_recurringItems.isNotEmpty ||
                          uncatSuggestions.isNotEmpty ||
                          categorySuggestions.isNotEmpty)
                        _buildUnifiedBudgetCard(
                          recurring: _recurringItems,
                          uncat: uncatSuggestions,
                          categories: categorySuggestions,
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: const Border(
                        top: BorderSide(width: 0.5, color: Colors.black12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _SelectedTotalBadge(
                              amount: _selectedTotal(),
                            ),
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

  void _pruneUncatControllers(Set<String> keep) {
    _uncatNameOverrides.removeWhere((k, _) => !keep.contains(k));
    _uncatAmountOverrides.removeWhere((k, _) => !keep.contains(k));
    _selectedUncatKeys.removeWhere((k) => !keep.contains(k));
  }

  void _syncRecurringAmountControllers(
    Map<int, _RecurringBudgetItem> lookup,
    Map<int, String> previousAmounts,
    Map<int, String> budgetPrefills,
  ) {
    final validIds = lookup.keys.toSet();
    final removeIds = _recurringAmountCtrls.keys
        .where((id) => !validIds.contains(id))
        .toList();
    for (final id in removeIds) {
      _recurringAmountCtrls[id]?.dispose();
      _recurringAmountCtrls.remove(id);
    }
    for (final entry in lookup.entries) {
      final id = entry.key;
      final existing = _recurringAmountCtrls[id];
      final defaultText = previousAmounts[id] ??
          budgetPrefills[id] ??
          entry.value.weeklyAmount.toStringAsFixed(2);
      if (existing == null) {
        _recurringAmountCtrls[id] = TextEditingController(text: defaultText);
      } else {
        existing.text = defaultText;
      }
    }
  }

  String _uncatKey(BudgetSuggestionModel s) {
    final descriptionKey = (s.description ?? '').trim().toLowerCase();
    if (descriptionKey.isNotEmpty) return descriptionKey;
    final categoryKey = (s.categoryName ?? '').trim().toLowerCase();
    if (categoryKey.isNotEmpty) return categoryKey;
    return 'uncat-${s.hashCode}';
  }

  double _uncatAmountValue(String key, BudgetSuggestionModel suggestion) {
    final text = _uncatAmountOverrides[key] ?? '';
    final resolved = text.trim().isEmpty
        ? suggestion.weeklySuggested.toStringAsFixed(2)
        : text;
    return _parseAmount(resolved);
  }

  String _uncatResolvedName(String key, BudgetSuggestionModel suggestion) {
    final override = _uncatNameOverrides[key]?.trim();
    if (override != null && override.isNotEmpty) return override;
    return suggestion.categoryName;
  }

  bool _isUncatSelected(String key) => _selectedUncatKeys.contains(key);

  Future<void> _handleUncatToggle({
    required String key,
    required BudgetSuggestionModel suggestion,
    required bool checked,
  }) async {
    if (checked) {
      final confirmed = await _promptForUncatSelection(key, suggestion);
      if (!confirmed) return;
      setState(() {
        _selectedUncatKeys.add(key);
      });
    } else {
      setState(() {
        _selectedUncatKeys.remove(key);
      });
    }
  }

  Future<bool> _promptForUncatSelection(
    String key,
    BudgetSuggestionModel suggestion,
  ) async {
    final currentName = _uncatResolvedName(key, suggestion);
    final currentAmount = _uncatAmountOverrides[key] ??
        suggestion.weeklySuggested.toStringAsFixed(2);
    final result = await _showUncategorizedEditor(
      title: suggestion.categoryName,
      initialName: currentName,
      initialAmount: currentAmount,
    );
    if (result == null) return false;
    _applyUncatOverrides(
      key: key,
      suggestion: suggestion,
      name: result.name,
      amount: result.amount,
    );
    return true;
  }

  void _toggleRecurringExpanded() {
    setState(() => _recurringExpanded = !_recurringExpanded);
  }

  List<BudgetSuggestionModel> _categorySuggestions() {
    final base = _suggestions
        .where((s) => !s.isUncategorizedGroup && !s.hasRecurring)
        .toList(growable: false);
    return base;
  }

  Widget _buildUnifiedBudgetCard({
    required List<_RecurringBudgetItem> recurring,
    required List<BudgetSuggestionModel> uncat,
    required List<BudgetSuggestionModel> categories,
  }) {
    final combinedRows = _combinedCategoryRows(uncat, categories);
    final hasRecurring = recurring.isNotEmpty;
    final hasCategories = combinedRows.isNotEmpty;
    if (!hasRecurring && !hasCategories) {
      return const SizedBox.shrink();
    }

    final sections = <Widget>[];
    if (hasRecurring) {
      sections.add(_buildRecurringHeader(recurring));
      if (_recurringExpanded) {
        sections.add(const Divider(height: 1));
        for (var i = 0; i < recurring.length; i++) {
          sections.add(_buildRecurringRow(recurring[i]));
          if (i != recurring.length - 1) {
            sections.add(const Divider(height: 1));
          }
        }
      }
    }

    if (hasRecurring && hasCategories) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 4));
      }
      sections.add(const _WeeklyExpenditureDivider());
    }

    for (var i = 0; i < combinedRows.length; i++) {
      final row = combinedRows[i];
      sections.add(
        row.isUncategorized
            ? _buildUncategorizedRow(row.suggestion)
            : _buildCategoryRow(row.suggestion),
      );
      if (i != combinedRows.length - 1) {
        sections.add(const Divider(height: 1));
      }
    }

    final recurringRowEstimate =
        hasRecurring ? 1 + (_recurringExpanded ? recurring.length : 0) : 0;
    final estimatedRows = recurringRowEstimate +
        (hasRecurring && hasCategories ? 1 : 0) +
        combinedRows.length;
    final maxHeight = min(max(estimatedRows, 1) * 120.0, 560.0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Select the essential expenses you would like to budget for.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hold to edit and name transactions.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: maxHeight,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const BouncingScrollPhysics(),
              children: sections,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringRow(_RecurringBudgetItem item) {
    final rid = item.recurringId;
    if (rid == null) return const SizedBox.shrink();
    final alreadyAdded = _selectedRecurringIds.contains(rid);
    final paymentLabel = item.frequency == 'monthly'
        ? 'Monthly payment: \$${item.amount.toStringAsFixed(2)}'
        : 'Weekly payment: \$${item.amount.toStringAsFixed(2)}';
    final weeklyLimit = _recurringAmountValue(rid, item).toStringAsFixed(2);
    final weeklyLine = 'Weekly limit: \$${weeklyLimit}';

    final showCategoryFirst = item.label.trim().isNotEmpty;
    final primaryName = showCategoryFirst
        ? item.label
        : (item.transactionName ?? item.label);
    final rawSecondary = showCategoryFirst ? item.transactionName : null;
    final secondaryName =
        (rawSecondary != null &&
            rawSecondary.trim().isNotEmpty &&
            rawSecondary.trim().toLowerCase() !=
                primaryName.trim().toLowerCase())
        ? rawSecondary
        : null;
    final emoji = _recurringEmoji(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _editRecurringAmount(item),
        child: Container(
          decoration: _rowDecoration(alreadyAdded),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (secondaryName != null &&
                        secondaryName.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          secondaryName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(paymentLabel, style: const TextStyle(fontSize: 12)),
                    Text(
                      weeklyLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: alreadyAdded,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => _toggleRecurringSelection(item, v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleRecurringSelection(_RecurringBudgetItem item, bool checked) {
    final rid = item.recurringId;
    if (rid == null) return;
    setState(() {
      if (checked) {
        _selectedRecurringIds.add(rid);
        _recurringAmountCtrls.putIfAbsent(
          rid,
          () =>
              TextEditingController(text: item.weeklyAmount.toStringAsFixed(2)),
        );
      } else {
        _selectedRecurringIds.remove(rid);
      }
    });
  }

  List<_CombinedCategoryRow> _combinedCategoryRows(
    List<BudgetSuggestionModel> uncat,
    List<BudgetSuggestionModel> items,
  ) {
    final rows = <_CombinedCategoryRow>[
      ...uncat.map(
        (s) => _CombinedCategoryRow(suggestion: s, isUncategorized: true),
      ),
      ...items.map(
        (s) => _CombinedCategoryRow(suggestion: s, isUncategorized: false),
      ),
    ];
    rows.sort((a, b) {
      final txCmp = b.suggestion.txCount.compareTo(a.suggestion.txCount);
      if (txCmp != 0) return txCmp;
      final spendCmp = b.suggestion.weeklySuggested.compareTo(
        a.suggestion.weeklySuggested,
      );
      if (spendCmp != 0) return spendCmp;
      return a.suggestion.categoryName.toLowerCase().compareTo(
        b.suggestion.categoryName.toLowerCase(),
      );
    });
    return rows;
  }

  Widget _buildRecurringHeader(List<_RecurringBudgetItem> items) {
    final recurringIds =
        items.map((item) => item.recurringId).whereType<int>().toSet();
    final selectedCount = _selectedRecurringIds
        .where((id) => recurringIds.contains(id))
        .length;
    final total = recurringIds.length;
    final subtitle = total == 0
        ? 'No recurring expenses detected yet.'
        : '$selectedCount of $total in your plan · tap to ${_recurringExpanded ? 'hide' : 'show'}';
    final title = widget.editMode
        ? 'Recurring essentials'
        : 'Recurring essentials (auto-selected)';

    return InkWell(
      onTap: _toggleRecurringExpanded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.autorenew,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(_recurringExpanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  String _categoryEmoji(BudgetSuggestionModel suggestion) {
    if (suggestion.isUncategorizedGroup) {
      return CategoryEmojiHelper.uncategorizedEmoji;
    }
    return _emojiHelper?.emojiForName(suggestion.categoryName) ??
        CategoryEmojiHelper.defaultEmoji;
  }

  String _recurringEmoji(_RecurringBudgetItem item) {
    final label = item.label.trim().isNotEmpty
        ? item.label
        : (item.transactionName ?? 'Recurring expense');
    return _emojiHelper?.emojiForName(label) ??
        CategoryEmojiHelper.defaultEmoji;
  }

  BoxDecoration _rowDecoration(bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: isSelected
          ? scheme.primary.withOpacity(0.08)
          : scheme.surfaceVariant.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected ? scheme.primary.withOpacity(0.35) : Colors.black12,
      ),
    );
  }

  Future<void> _editRecurringAmount(_RecurringBudgetItem item) async {
    final rid = item.recurringId;
    if (rid == null) return;
    final controller = _ensureRecurringAmountController(rid, item);
    final initial = controller.text.trim().isEmpty
        ? item.weeklyAmount.toStringAsFixed(2)
        : controller.text;
    final updated = await _showAmountEditor(
      title: item.label,
      initialValue: initial,
      helperText: 'Set the weekly limit for this recurring budget.',
    );
    if (updated == null) return;
    setState(() {
      controller.text = _parseAmount(updated).toStringAsFixed(2);
    });
  }

  Future<void> _editCategoryAmount(BudgetSuggestionModel s) async {
    final controller = _amountCtrls[s.categoryId];
    if (controller == null) return;
    final updated = await _showAmountEditor(
      title: s.categoryName,
      initialValue: controller.text,
      helperText: 'Set the weekly limit for this category.',
    );
    if (updated == null) return;
    setState(() {
      controller.text = _parseAmount(updated).toStringAsFixed(2);
    });
  }

  Future<void> _editUncategorizedItem(
    String key,
    BudgetSuggestionModel suggestion,
  ) async {
    final currentName = _uncatResolvedName(key, suggestion);
    final currentAmount =
        _uncatAmountOverrides[key] ??
        suggestion.weeklySuggested.toStringAsFixed(2);
    final result = await _showUncategorizedEditor(
      title: suggestion.categoryName,
      initialName: currentName,
      initialAmount: currentAmount,
    );
    if (result == null) return;
    _applyUncatOverrides(
      key: key,
      suggestion: suggestion,
      name: result.name,
      amount: result.amount,
    );
  }

  void _applyUncatOverrides({
    required String key,
    required BudgetSuggestionModel suggestion,
    required String name,
    required String amount,
  }) {
    final normalizedAmount = _parseAmount(amount).toStringAsFixed(2);
    final defaultAmount = suggestion.weeklySuggested.toStringAsFixed(2);
    setState(() {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty || trimmedName == suggestion.categoryName) {
        _uncatNameOverrides.remove(key);
      } else {
        _uncatNameOverrides[key] = trimmedName;
      }
      if (normalizedAmount == defaultAmount) {
        _uncatAmountOverrides.remove(key);
      } else {
        _uncatAmountOverrides[key] = normalizedAmount;
      }
    });
  }

  Future<String?> _showAmountEditor({
    required String title,
    required String initialValue,
    String? helperText,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (helperText != null) ...[
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weekly limit',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, controller.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<_UncatEditResult?> _showUncategorizedEditor({
    required String title,
    required String initialName,
    required String initialAmount,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final amountController = TextEditingController(text: initialAmount);
    final result = await showModalBottomSheet<_UncatEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
              const SizedBox(height: 16),
              Text(
                'Edit budget',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Budget name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weekly limit',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _UncatEditResult(
                        name: nameController.text,
                        amount: amountController.text,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
    });
    return result;
  }

  Widget _buildUncategorizedRow(BudgetSuggestionModel s) {
    final key = _uncatKey(s);
    final selected = _isUncatSelected(key);
    final emoji = CategoryEmojiHelper.uncategorizedEmoji;
    final amount = _uncatAmountValue(key, s);
    final displayName = _uncatResolvedName(key, s);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _editUncategorizedItem(key, s),
        child: Container(
          decoration: _rowDecoration(selected),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Weekly suggested: \$${s.weeklySuggested.toStringAsFixed(2)} • tx: ${s.txCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        if ((s.description ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Top match: ${s.description}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Suggested weekly limit: \$${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                onChanged: (v) => _handleUncatToggle(
                  key: key,
                  suggestion: s,
                  checked: v ?? false,
                ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Hold to name this budget',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(BudgetSuggestionModel s) {
    final selected = _selected[s.categoryId] ?? false;
    final emoji = _categoryEmoji(s);
    final ctrl = _amountCtrls[s.categoryId];
    final amountLabel = ctrl != null
        ? _parseAmount(ctrl.text).toStringAsFixed(2)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _editCategoryAmount(s),
        child: Container(
          decoration: _rowDecoration(selected),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.categoryName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amountLabel != null
                          ? 'Weekly limit: \$${amountLabel}'
                          : 'Weekly suggested: \$${s.weeklySuggested.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (v) =>
                    setState(() => _selected[s.categoryId] = v ?? false),
              ),
            ],
          ),
        ),
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
    for (final rid in _selectedRecurringIds) {
      final item = _recurringItemLookup[rid];
      if (item != null) {
        sum += _recurringAmountValue(rid, item);
      }
    }
    final uncatMap = {
      for (final s in _suggestions.where((s) => s.isUncategorizedGroup))
        _uncatKey(s): s,
    };
    for (final key in _selectedUncatKeys) {
      final suggestion = uncatMap[key];
      if (suggestion == null) continue;
      sum += _uncatAmountValue(key, suggestion);
    }
    return sum;
  }

  double _recurringAmountValue(int rid, _RecurringBudgetItem item) {
    final text = _recurringAmountCtrls[rid]?.text ?? '';
    final resolved = text.trim().isEmpty
        ? item.weeklyAmount.toStringAsFixed(2)
        : text;
    return _parseAmount(resolved);
  }

  TextEditingController _ensureRecurringAmountController(
    int id,
    _RecurringBudgetItem item,
  ) {
    return _recurringAmountCtrls.putIfAbsent(
      id,
      () => TextEditingController(text: item.weeklyAmount.toStringAsFixed(2)),
    );
  }
}

class _WeeklyExpenditureDivider extends StatelessWidget {
  const _WeeklyExpenditureDivider();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 12,
      letterSpacing: 0.4,
      color: Colors.black54,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.black12)),
          const SizedBox(width: 12),
          Text('your average weekly expenditure', style: textStyle),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Colors.black12)),
        ],
      ),
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
      child: FittedBox(
        child: Text('Selected: \$${amount.toStringAsFixed(2)}/wk'),
      ),
    );
  }
}

/// Lightweight view-model for recurring expenses surfaced in the builder.
class _CombinedCategoryRow {
  final BudgetSuggestionModel suggestion;
  final bool isUncategorized;
  const _CombinedCategoryRow({
    required this.suggestion,
    required this.isUncategorized,
  });
}

class _UncatEditResult {
  final String name;
  final String amount;
  const _UncatEditResult({required this.name, required this.amount});
}

class _RecurringBudgetItem {
  final int? recurringId;
  final int categoryId;
  final String label;
  final String frequency;
  final double amount;
  final double weeklyAmount;
  final String? transactionName;

  const _RecurringBudgetItem({
    required this.recurringId,
    required this.categoryId,
    required this.label,
    required this.frequency,
    required this.amount,
    required this.weeklyAmount,
    this.transactionName,
  });

  String get frequencyLabel => frequency == 'monthly' ? 'Monthly' : 'Weekly';
}
