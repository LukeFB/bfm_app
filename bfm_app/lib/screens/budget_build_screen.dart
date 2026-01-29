/// ---------------------------------------------------------------------------
/// File: lib/screens/budget_build_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Budget builder screen for selecting spending categories.
///   - Shows category suggestions based on transaction history.
///   - Subscriptions are handled separately in the subscriptions screen.
/// ---------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/models/budget_suggestion_model.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';

class BudgetBuildScreen extends StatefulWidget {
  const BudgetBuildScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<BudgetBuildScreen> createState() => _BudgetBuildScreenState();
}

class _BudgetBuildScreenState extends State<BudgetBuildScreen> {
  bool _loading = true;
  bool _saving = false;
  List<BudgetSuggestionModel> _suggestions = [];
  List<BudgetSuggestionModel> _baseSuggestions = [];
  final Map<int, BudgetSuggestionModel> _manualSuggestions = {};
  final Map<int?, bool> _selected = {};
  final Map<int?, TextEditingController> _amountCtrls = {};
  final Set<String> _selectedUncatKeys = {};
  final Map<String, String> _uncatNameOverrides = {};
  final Map<String, String> _uncatAmountOverrides = {};
  CategoryEmojiHelper? _emojiHelper;
  double _subscriptionTotal = 0.0;

  List<BudgetSuggestionModel> _composeSuggestionsList() => [
        ..._manualSuggestions.values,
        ..._baseSuggestions,
      ];

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
    final previousUncatSelection = Set<String>.from(_selectedUncatKeys);
    final previousUncatNames = Map<String, String>.from(_uncatNameOverrides);
    final previousUncatAmounts =
        Map<String, String>.from(_uncatAmountOverrides);
    setState(() => _loading = true);

    final list = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );
    final emojiHelper = await CategoryEmojiHelper.ensureLoaded();

    // Calculate subscription total from existing recurring budgets
    double subscriptionTotal = 0.0;
    final allBudgets = await BudgetRepository.getAll();
    for (final budget in allBudgets) {
      if (budget.recurringTransactionId != null) {
        subscriptionTotal += budget.weeklyLimit;
      }
    }

    Map<int, BudgetModel> existingBudgets = {};
    Map<int, String> existingBudgetNames = {};
    Map<String, BudgetModel> existingUncatBudgets = {};

    if (widget.editMode) {
      final budgets = await BudgetRepository.getAll();
      for (final budget in budgets) {
        // Skip recurring budgets - handled in subscriptions screen
        if (budget.recurringTransactionId != null) continue;

        final catId = budget.categoryId;
        if (catId != null) {
          existingBudgets[catId] = budget;
        }
      }
      if (existingBudgets.isNotEmpty) {
        existingBudgetNames = await CategoryRepository.getNamesByIds(
          existingBudgets.keys,
        );
      }
      existingUncatBudgets = {
        for (final b in budgets)
          if ((b.uncategorizedKey?.trim().isNotEmpty ?? false) &&
              b.recurringTransactionId == null)
            b.uncategorizedKey!.trim().toLowerCase(): b,
      };
    }

    if (!mounted) return;

    final nextSelected = <int?, bool>{};
    final nextControllers = <int?, TextEditingController>{};
    final remainingManual =
        Map<int, BudgetSuggestionModel>.from(_manualSuggestions);

    for (final s in list.where((x) => !x.isUncategorizedGroup)) {
      final id = s.categoryId;
      if (id == null) continue;

      remainingManual.remove(id);

      final existingCtrl = _amountCtrls[id];
      nextControllers[id] = existingCtrl ??
          TextEditingController(text: s.weeklySuggested.toStringAsFixed(2));

      final previousAmount = previousAmounts[id];
      if (previousAmount != null) {
        nextControllers[id]!.text = previousAmount;
      } else {
        final budgetPrefill = existingBudgets[id];
        if (budgetPrefill != null) {
          nextControllers[id]!.text =
              budgetPrefill.weeklyLimit.toStringAsFixed(2);
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
      final presentUncatKeys =
          list.where((s) => s.isUncategorizedGroup).map(_uncatKey).toSet();
      for (final entry in existingUncatBudgets.entries) {
        if (presentUncatKeys.contains(entry.key)) continue;
        final budget = entry.value;
        final displayName = (budget.label?.trim().isNotEmpty ?? false)
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

    final restoredSelectedUncat =
        previousUncatSelection.where(nextUncatKeys.contains).toSet();
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
      _subscriptionTotal = subscriptionTotal;
      _loading = false;
    });

    _pruneUncatControllers(nextUncatKeys);
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

  Future<void> _saveSelected() async {
    if (_saving) return;
    setState(() => _saving = true);

    final periodStart = _mondayOfThisWeek();

    // Clear existing non-recurring budgets (preserves subscription budgets)
    // This ensures a fresh start whether in edit mode or onboarding
    await BudgetRepository.clearNonRecurring();

    // Save category budgets
    for (final s in _suggestions) {
      if (s.isUncategorizedGroup) continue;
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
    }

    // Save uncategorized budgets
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
    }

    if (!mounted) return;
    setState(() {
      _selectedUncatKeys.clear();
      _uncatNameOverrides.clear();
      _uncatAmountOverrides.clear();
      _saving = false;
    });

    // Navigate directly to dashboard (skip alerts)
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/dashboard',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uncatSuggestions = _uncategorizedSuggestions();
    final categorySuggestions = _categorySuggestions();
    final selectedTotal = _selectedTotal();
    final grandTotal = selectedTotal + _subscriptionTotal;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.editMode) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/subscriptions');
            }
          },
        ),
        title: Text(
          widget.editMode ? 'Edit spending budgets' : 'Set spending limits',
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
                Expanded(
                  child: (uncatSuggestions.isEmpty && categorySuggestions.isEmpty)
                      ? _buildEmptyState()
                      : Stack(
                          children: [
                            _buildCategoriesList(uncatSuggestions, categorySuggestions),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _buildStickyTotal(grandTotal),
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

  Widget _buildStickyTotal(double total) {
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
                '\$${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'total weekly budget',
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
                Icons.pie_chart_outline,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No spending data yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Once we have more transaction history, we'll suggest spending categories to budget.",
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

  Widget _buildCategoriesList(
    List<BudgetSuggestionModel> uncatSuggestions,
    List<BudgetSuggestionModel> categorySuggestions,
  ) {
    final combinedRows = _combinedCategoryRows(uncatSuggestions, categorySuggestions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      children: [
        // Header text
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Select your essential expenses to budget for them. Limits are based on your actual spending.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
        ),

        // Category cards
        if (combinedRows.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < combinedRows.length; i++) ...[
                  combinedRows[i].isUncategorized
                      ? _buildUncategorizedRow(combinedRows[i].suggestion)
                      : _buildCategoryRow(combinedRows[i].suggestion),
                  if (i < combinedRows.length - 1) 
                    Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<BudgetSuggestionModel> _uncategorizedSuggestions() {
    final list = _suggestions.where((s) => s.isUncategorizedGroup).toList();
    list.sort((a, b) => b.txCount.compareTo(a.txCount));
    return list;
  }

  List<BudgetSuggestionModel> _categorySuggestions() {
    return _suggestions
        .where((s) => !s.isUncategorizedGroup)
        .toList(growable: false);
  }

  void _pruneUncatControllers(Set<String> keep) {
    _uncatNameOverrides.removeWhere((k, _) => !keep.contains(k));
    _uncatAmountOverrides.removeWhere((k, _) => !keep.contains(k));
    _selectedUncatKeys.removeWhere((k) => !keep.contains(k));
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

  String _categoryEmoji(BudgetSuggestionModel suggestion) {
    if (suggestion.isUncategorizedGroup) {
      return CategoryEmojiHelper.uncategorizedEmoji;
    }
    return _emojiHelper?.emojiForName(suggestion.categoryName) ??
        CategoryEmojiHelper.defaultEmoji;
  }

  BoxDecoration _rowDecoration(bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: isSelected ? scheme.primary.withOpacity(0.08) : null,
      border: isSelected
          ? Border(
              left: BorderSide(
                width: 3,
                color: scheme.primary,
              ),
            )
          : null,
    );
  }

  Future<void> _editCategoryAmount(BudgetSuggestionModel s) async {
    final controller = _amountCtrls[s.categoryId];
    if (controller == null) return;
    final updated = await _showAmountEditor(
      title: s.categoryName,
      initialValue: controller.text,
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
    final currentAmount = _uncatAmountOverrides[key] ??
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
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: true,
                ),
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
    final nameFocusNode = FocusNode();
    var hasSelectedNameText = false;
    void selectAllNameText() {
      nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: nameController.text.length,
      );
    }

    selectAllNameText();
    nameFocusNode.addListener(() {
      if (nameFocusNode.hasFocus && !hasSelectedNameText) {
        hasSelectedNameText = true;
        selectAllNameText();
      }
    });
    final resolvedTitle = title.trim().isEmpty ? 'Edit budget' : title.trim();
    final result = await showDialog<_UncatEditResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            resolvedTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  focusNode: nameFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Name this budget',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Weekly limit',
                    prefixText: '\$',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _UncatEditResult(
                  name: nameController.text,
                  amount: amountController.text,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
      nameFocusNode.dispose();
    });
    return result;
  }

  Widget _buildUncategorizedRow(BudgetSuggestionModel s) {
    final key = _uncatKey(s);
    final selected = _isUncatSelected(key);
    final amount = _uncatAmountValue(key, s);
    final displayName = _uncatResolvedName(key, s);
    final emojiSource =
        displayName.trim().isNotEmpty ? displayName : (s.description ?? '').trim();
    final emoji = (emojiSource.isNotEmpty
            ? _emojiHelper?.emojiForName(emojiSource)
            : null) ??
        CategoryEmojiHelper.uncategorizedEmoji;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleUncatToggle(
        key: key,
        suggestion: s,
        checked: !selected,
      ),
      onLongPress: () => _editUncategorizedItem(key, s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: _rowDecoration(selected),
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
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.orange.shade700 : Colors.orange.shade600,
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
                            color: selected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Colors.grey.shade100,
                          ),
                          child: Text(
                            '\$${amount.toStringAsFixed(2)}/wk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'suggested',
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
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    width: 2,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black26,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
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
    final amount = ctrl != null ? _parseAmount(ctrl.text) : s.weeklySuggested;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected[s.categoryId] = !selected),
      onLongPress: () => _editCategoryAmount(s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: _rowDecoration(selected),
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
                      s.categoryName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.black : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            color: selected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                : Colors.grey.shade100,
                          ),
                          child: Text(
                            '\$${amount.toStringAsFixed(2)}/wk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'suggested',
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
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    width: 2,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black26,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
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

  int _selectedCount() {
    int count = 0;
    for (final s in _suggestions) {
      if (s.isUncategorizedGroup) continue;
      if (_selected[s.categoryId] ?? false) count++;
    }
    count += _selectedUncatKeys.length;
    return count;
  }

  Widget _buildFooter() {
    final count = _selectedCount();

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
              '$count selected',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Finish'),
              onPressed: _saving ? null : _saveSelected,
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
