/// ---------------------------------------------------------------------------
/// File: lib/screens/budgets_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/budgets` route from bottom navigation.
///
/// Purpose:
///   - Displays budget recommendations with expandable dropdowns for 
///     subscriptions, budgets, and uncategorized transactions.
///   - Detects changes in subscription amounts or budget averages and shows
///     orange warning indicators when values change by more than 10%.
/// ---------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bfm_app/models/budget_model.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/services/budget_seen_store.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/manual_budget_store.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:bfm_app/utils/category_emoji_helper.dart';
import 'package:bfm_app/widgets/help_icon_tooltip.dart';
import 'package:bfm_app/widgets/budget_tracking_card.dart';

const Color bfmBlue = Color(0xFF005494);
const Color bfmOrange = Color(0xFFFF6934);

/// Budget overview screen with chart and detailed breakdowns.
class BudgetsScreen extends StatefulWidget {
  /// When true, the screen is embedded in MainShell.
  final bool embedded;

  const BudgetsScreen({super.key, this.embedded = false});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  bool _loading = true;
  _BudgetsData? _data;
  bool _subscriptionsExpanded = false;
  bool _budgetsExpanded = false;
  
  // Selection and amount tracking for subscriptions
  final Set<int> _selectedRecurringIds = {};
  final Map<int, double> _recurringCurrentAmounts = {}; // Current working amounts
  final Map<int, bool> _recurringIsNew = {}; // Track if item is truly new (never seen)
  final Map<int, bool> _recurringShowAlert = {}; // Show orange alert indicator
  final Map<int, bool> _recurringHasSuggestion = {}; // Show suggested amount text
  
  // Selection and amount tracking for categories
  final Map<int?, bool> _selectedCategories = {};
  final Map<int?, double> _categoryCurrentAmounts = {}; // Current working amounts
  final Map<int?, bool> _categoryIsNew = {}; // Track if item is truly new (never seen)
  final Map<int?, bool> _categoryShowAlert = {}; // Show orange alert indicator
  final Map<int?, bool> _categoryHasSuggestion = {}; // Show suggested amount text
  
  // Uncategorized tracking
  final Set<String> _selectedUncatKeys = {};
  final Map<String, String> _uncatNameOverrides = {};
  final Map<String, double> _uncatCurrentAmounts = {};
  final Map<String, bool> _uncatIsNew = {}; // Track if item is truly new (never seen)
  final Map<String, bool> _uncatShowAlert = {}; // Show orange alert indicator
  final Map<String, bool> _uncatHasSuggestion = {}; // Show suggested amount text
  
  // Manual budget tracking (user-created budgets not from detected transactions)
  final List<_ManualBudgetItem> _manualBudgets = [];
  final Set<int> _selectedManualBudgetIndices = {}; // Track which manual budgets are selected
  
  // Seen data loaded from persistent store (tracks what user has acknowledged)
  Set<int> _seenSubscriptionIds = {};
  Map<int, double> _seenSubscriptionAmounts = {};
  Set<int> _seenCategoryIds = {};
  Map<int, double> _seenCategoryAmounts = {};
  Set<String> _seenUncatKeys = {};
  Map<String, double> _seenUncatAmounts = {};
  
  CategoryEmojiHelper? _emojiHelper;

  static const double _kWeeksPerMonth = 4.345;
  static const double _kSubscriptionTolerance = 0.0; // 0% - any change triggers suggestion
  static const double _kBudgetTolerance = 0.20; // 20% tolerance for budgets

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Save changes and mark all items as seen when leaving the screen
    _saveChanges(showSnackbar: false);
    super.dispose();
  }

  /// Check if a value has changed beyond tolerance
  bool _hasSignificantChange(double oldValue, double newValue, {double tolerance = 0.10}) {
    if (oldValue <= 0) return newValue > 0;
    final percentChange = ((newValue - oldValue) / oldValue).abs();
    return percentChange > tolerance;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    await TransactionSyncService().syncIfStale();

    // Load seen data from persistent store
    final seenResults = await Future.wait([
      BudgetSeenStore.getSeenSubscriptionIds(),
      BudgetSeenStore.getSeenSubscriptionAmounts(),
      BudgetSeenStore.getSeenCategoryIds(),
      BudgetSeenStore.getSeenCategoryAmounts(),
      BudgetSeenStore.getSeenUncatKeys(),
      BudgetSeenStore.getSeenUncatAmounts(),
    ]);
    
    _seenSubscriptionIds = seenResults[0] as Set<int>;
    _seenSubscriptionAmounts = seenResults[1] as Map<int, double>;
    _seenCategoryIds = seenResults[2] as Set<int>;
    _seenCategoryAmounts = seenResults[3] as Map<int, double>;
    _seenUncatKeys = seenResults[4] as Set<String>;
    _seenUncatAmounts = seenResults[5] as Map<String, double>;

    final results = await Future.wait([
      DashboardService.getWeeklyIncome(),
      DashboardService.getTotalBudgeted(),
      DashboardService.getSpentOnBudgets(),
      DashboardService.getDiscretionaryWeeklyBudget(),
      DashboardService.getTotalExpensesThisWeek(),
      _fetchSubscriptions(),
      _fetchCategoryBudgets(),
      _fetchUncategorizedBudgets(),
      CategoryEmojiHelper.ensureLoaded(),
      DashboardService.getBudgetTrackingData(),
    ]);

    final weeklyIncome = results[0] as double;
    final totalBudgeted = results[1] as double;
    final spentOnBudgets = results[2] as double;
    final leftToSpend = results[3] as double;
    final totalExpenses = results[4] as double;
    final subscriptions = results[5] as List<_SubscriptionItem>;
    final categoryBudgets = results[6] as List<_CategoryBudgetItem>;
    final uncategorizedBudgets = results[7] as List<_UncategorizedItem>;
    final emojiHelper = results[8] as CategoryEmojiHelper;
    final trackingItems = results[9] as List<BudgetTrackingItem>;

    final nonBudgetedSpend = (totalExpenses - spentOnBudgets).clamp(0.0, double.infinity);

    // Get existing budgets (user selections)
    final existingBudgets = await BudgetRepository.getAll();
    final existingRecurringBudgets = <int, BudgetModel>{};
    final existingCategoryBudgets = <int, BudgetModel>{};
    final existingUncatBudgets = <String, BudgetModel>{};
    
    for (final b in existingBudgets) {
      if (b.recurringTransactionId != null) {
        existingRecurringBudgets[b.recurringTransactionId!] = b;
      } else if (b.categoryId != null && b.goalId == null) {
        existingCategoryBudgets[b.categoryId!] = b;
      } else if (b.uncategorizedKey != null) {
        existingUncatBudgets[b.uncategorizedKey!.toLowerCase()] = b;
      }
      // Note: Manual budgets are now loaded from ManualBudgetStore, not DB
    }
    
    // Load manual budgets from persistent store (remembers unselected ones too)
    final storedManualBudgets = await ManualBudgetStore.getAll();
    _manualBudgets.clear();
    _selectedManualBudgetIndices.clear();
    for (int i = 0; i < storedManualBudgets.length; i++) {
      final stored = storedManualBudgets[i];
      _manualBudgets.add(_ManualBudgetItem(
        id: null,
        name: stored.name,
        weeklyLimit: stored.weeklyLimit,
      ));
      if (stored.isSelected) {
        _selectedManualBudgetIndices.add(i);
      }
    }

    // Process subscriptions
    for (final sub in subscriptions) {
      final rid = sub.recurringId;
      if (rid == null) continue;
      
      final existingBudget = existingRecurringBudgets[rid];
      final hasBeenSeen = _seenSubscriptionIds.contains(rid);
      final seenAmount = _seenSubscriptionAmounts[rid];
      final detectedAmount = sub.weeklyAmount;
      
      // Determine if truly new (never seen before)
      final isTrulyNew = !hasBeenSeen;
      
      // hasSuggestion: saved budget differs from detected (show "Suggested: $X" text)
      // showAlert: detected differs from what user has acknowledged (show orange indicator)
      bool hasSuggestion = false;
      bool showAlert = false;
      
      if (existingBudget != null) {
        _selectedRecurringIds.add(rid);
        _recurringCurrentAmounts[rid] = existingBudget.weeklyLimit;
        // Show suggestion if saved differs from detected (0% tolerance for subscriptions)
        hasSuggestion = _hasSignificantChange(existingBudget.weeklyLimit, detectedAmount, tolerance: _kSubscriptionTolerance);
        // Show alert only if detected differs from what user acknowledged
        if (seenAmount != null) {
          showAlert = _hasSignificantChange(seenAmount, detectedAmount, tolerance: _kSubscriptionTolerance);
        } else {
          showAlert = hasSuggestion; // First time seeing this difference
        }
      } else {
        _recurringCurrentAmounts[rid] = detectedAmount;
      }
      
      _recurringIsNew[rid] = isTrulyNew;
      _recurringHasSuggestion[rid] = hasSuggestion;
      _recurringShowAlert[rid] = showAlert || isTrulyNew;
    }

    // Process category budgets
    for (final cat in categoryBudgets) {
      final catId = cat.categoryId;
      if (catId == null) continue;
      
      final existingBudget = existingCategoryBudgets[catId];
      final hasBeenSeen = _seenCategoryIds.contains(catId);
      final seenAmount = _seenCategoryAmounts[catId];
      final detectedAmount = cat.weeklyLimit;
      
      // Determine if truly new (never seen before)
      final isTrulyNew = !hasBeenSeen;
      
      // hasSuggestion: saved budget differs from detected (show "Suggested: $X" text)
      // showAlert: detected differs from what user has acknowledged (show orange indicator)
      bool hasSuggestion = false;
      bool showAlert = false;
      
      if (existingBudget != null) {
        _selectedCategories[catId] = true;
        _categoryCurrentAmounts[catId] = existingBudget.weeklyLimit;
        // Show suggestion if saved budget differs from detected (20% tolerance for budgets)
        hasSuggestion = _hasSignificantChange(existingBudget.weeklyLimit, detectedAmount, tolerance: _kBudgetTolerance);
        // Show alert only if detected differs from what user acknowledged
        if (seenAmount != null) {
          showAlert = _hasSignificantChange(seenAmount, detectedAmount, tolerance: _kBudgetTolerance);
        } else {
          showAlert = hasSuggestion; // First time seeing this difference
        }
      } else {
        _selectedCategories[catId] = false;
        _categoryCurrentAmounts[catId] = detectedAmount;
      }
      
      _categoryIsNew[catId] = isTrulyNew;
      _categoryHasSuggestion[catId] = hasSuggestion;
      _categoryShowAlert[catId] = showAlert || isTrulyNew;
    }

    // Process uncategorized budgets
    for (final uncat in uncategorizedBudgets) {
      final key = uncat.key;
      
      final existingBudget = existingUncatBudgets[key];
      final hasBeenSeen = _seenUncatKeys.contains(key);
      final seenAmount = _seenUncatAmounts[key];
      final detectedAmount = uncat.weeklyAmount;
      
      // Determine if truly new (never seen before)
      final isTrulyNew = !hasBeenSeen;
      
      // hasSuggestion: saved budget differs from detected (show "Suggested: $X" text)
      // showAlert: detected differs from what user has acknowledged (show orange indicator)
      bool hasSuggestion = false;
      bool showAlert = false;
      
      if (existingBudget != null) {
        _selectedUncatKeys.add(key);
        _uncatCurrentAmounts[key] = existingBudget.weeklyLimit;
        // Show suggestion if saved budget differs from detected (20% tolerance for budgets)
        hasSuggestion = _hasSignificantChange(existingBudget.weeklyLimit, detectedAmount, tolerance: _kBudgetTolerance);
        // Show alert only if detected differs from what user acknowledged
        if (seenAmount != null) {
          showAlert = _hasSignificantChange(seenAmount, detectedAmount, tolerance: _kBudgetTolerance);
        } else {
          showAlert = hasSuggestion; // First time seeing this difference
        }
        if (existingBudget.label != null && existingBudget.label!.isNotEmpty) {
          _uncatNameOverrides[key] = existingBudget.label!;
        }
      } else {
        _uncatCurrentAmounts[key] = detectedAmount;
      }
      
      _uncatIsNew[key] = isTrulyNew;
      _uncatHasSuggestion[key] = hasSuggestion;
      _uncatShowAlert[key] = showAlert || isTrulyNew;
    }

    if (!mounted) return;
    setState(() {
      _data = _BudgetsData(
        weeklyIncome: weeklyIncome,
        totalBudgeted: totalBudgeted,
        spentOnBudgets: spentOnBudgets,
        leftToSpend: leftToSpend,
        discretionarySpent: nonBudgetedSpend,
        subscriptions: subscriptions,
        categoryBudgets: categoryBudgets,
        uncategorizedBudgets: uncategorizedBudgets,
        trackingItems: trackingItems,
      );
      _emojiHelper = emojiHelper;
      _loading = false;
    });
  }

  Future<List<_SubscriptionItem>> _fetchSubscriptions() async {
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

      return _SubscriptionItem(
        recurringId: r.id,
        categoryId: r.categoryId,
        name: label,
        transactionName: transactionName,
        frequency: freq,
        amount: r.amount,
        weeklyAmount: double.parse(weeklyAmount.toStringAsFixed(2)),
      );
    }).toList();

    items.sort((a, b) => b.weeklyAmount.compareTo(a.weeklyAmount));
    return items;
  }

  Future<List<_CategoryBudgetItem>> _fetchCategoryBudgets() async {
    final suggestions = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );
    
    final categorySuggestions = suggestions.where((s) => 
        !s.isUncategorizedGroup && s.categoryId != null).toList();

    if (categorySuggestions.isEmpty) return const [];

    final items = categorySuggestions.map((s) {
      return _CategoryBudgetItem(
        categoryId: s.categoryId,
        name: s.categoryName,
        weeklyLimit: s.weeklySuggested,
        txCount: s.txCount,
      );
    }).toList();

    items.sort((a, b) {
      final txCmp = b.txCount.compareTo(a.txCount);
      if (txCmp != 0) return txCmp;
      return b.weeklyLimit.compareTo(a.weeklyLimit);
    });
    
    return items;
  }

  Future<List<_UncategorizedItem>> _fetchUncategorizedBudgets() async {
    final suggestions = await BudgetAnalysisService.getCategoryWeeklyBudgetSuggestions(
      minWeekly: 5.0,
    );
    
    final uncatSuggestions = suggestions.where((s) => s.isUncategorizedGroup).toList();

    if (uncatSuggestions.isEmpty) return const [];

    final items = uncatSuggestions.map((s) {
      final key = (s.description ?? s.categoryName).trim().toLowerCase();
      return _UncategorizedItem(
        key: key,
        name: s.categoryName,
        description: s.description,
        weeklyAmount: s.weeklySuggested,
        txCount: s.txCount,
      );
    }).toList();

    items.sort((a, b) => b.txCount.compareTo(a.txCount));
    return items;
  }

  Future<void> _forceSync() async {
    await TransactionSyncService().syncNow(forceRefresh: true);
    if (!mounted) return;
    await _load();
  }

  String _mondayOfThisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
  }

  double _parseAmount(double? amount) {
    if (amount == null || amount.isNaN || amount.isInfinite) return 0.0;
    return max(0.0, amount);
  }

  Future<void> _saveChanges({bool showSnackbar = true}) async {
    final periodStart = _mondayOfThisWeek();
    int saved = 0;

    await BudgetRepository.clearAll();

    // Save selected recurring items
    for (final rid in _selectedRecurringIds) {
      final weeklyLimit = _parseAmount(_recurringCurrentAmounts[rid]);
      if (weeklyLimit <= 0) continue;
      
      final sub = _data?.subscriptions.firstWhere(
        (s) => s.recurringId == rid,
        orElse: () => _SubscriptionItem(
          recurringId: null, categoryId: 0, name: '', frequency: '', amount: 0, weeklyAmount: 0,
        ),
      );
      if (sub?.recurringId == null) continue;
      
      final m = BudgetModel(
        categoryId: sub!.categoryId,
        recurringTransactionId: rid,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
    }

    // Save selected category budgets
    for (final entry in _selectedCategories.entries) {
      if (entry.value != true || entry.key == null) continue;
      
      final weeklyLimit = _parseAmount(_categoryCurrentAmounts[entry.key]);
      if (weeklyLimit <= 0) continue;
      
      final m = BudgetModel(
        categoryId: entry.key,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
    }

    // Save selected uncategorized items
    for (final key in _selectedUncatKeys) {
      final weeklyLimit = _parseAmount(_uncatCurrentAmounts[key]);
      if (weeklyLimit <= 0) continue;
      
      final uncat = _data?.uncategorizedBudgets.firstWhere(
        (u) => u.key == key,
        orElse: () => _UncategorizedItem(key: '', name: '', weeklyAmount: 0, txCount: 0),
      );
      if (uncat == null || uncat.key.isEmpty) continue;
      
      final displayName = _uncatNameOverrides[key] ?? uncat.name;
      
      final m = BudgetModel(
        categoryId: null,
        label: displayName,
        uncategorizedKey: key,
        weeklyLimit: weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
    }

    // Save selected manual budgets to DB (for budget tracking)
    for (int i = 0; i < _manualBudgets.length; i++) {
      if (!_selectedManualBudgetIndices.contains(i)) continue;
      final manual = _manualBudgets[i];
      final m = BudgetModel(
        categoryId: null,
        label: manual.name,
        weeklyLimit: manual.weeklyLimit,
        periodStart: periodStart,
      );
      await BudgetRepository.insert(m);
      saved += 1;
    }
    
    // Save ALL manual budgets (including unselected) to persistent store
    final manualBudgetsToStore = <ManualBudget>[];
    for (int i = 0; i < _manualBudgets.length; i++) {
      manualBudgetsToStore.add(ManualBudget(
        name: _manualBudgets[i].name,
        weeklyLimit: _manualBudgets[i].weeklyLimit,
        isSelected: _selectedManualBudgetIndices.contains(i),
      ));
    }
    await ManualBudgetStore.saveAll(manualBudgetsToStore);

    // Mark ALL items as seen with their current detected amounts
    // This ensures items are no longer marked as "new" after save
    await _markAllItemsAsSeen();

    if (!mounted) return;
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $saved budget${saved == 1 ? '' : 's'}')),
      );
    }
    
    // Clear new/alert flags after save
    _recurringIsNew.clear();
    _recurringShowAlert.clear();
    _recurringHasSuggestion.clear();
    _categoryIsNew.clear();
    _categoryShowAlert.clear();
    _categoryHasSuggestion.clear();
    _uncatIsNew.clear();
    _uncatShowAlert.clear();
    _uncatHasSuggestion.clear();
    
    await _load();
  }
  
  /// Marks all current items as seen with their detected amounts.
  Future<void> _markAllItemsAsSeen() async {
    // Build maps of current detected amounts for all items
    final subAmounts = <int, double>{};
    for (final sub in _data?.subscriptions ?? []) {
      if (sub.recurringId != null) {
        subAmounts[sub.recurringId!] = sub.weeklyAmount;
      }
    }
    
    final catAmounts = <int, double>{};
    for (final cat in _data?.categoryBudgets ?? []) {
      if (cat.categoryId != null) {
        catAmounts[cat.categoryId!] = cat.weeklyLimit;
      }
    }
    
    final uncatAmounts = <String, double>{};
    for (final uncat in _data?.uncategorizedBudgets ?? []) {
      uncatAmounts[uncat.key] = uncat.weeklyAmount;
    }
    
    // Persist to seen store
    await Future.wait([
      BudgetSeenStore.markAllSubscriptionsSeen(subAmounts),
      BudgetSeenStore.markAllCategoriesSeen(catAmounts),
      BudgetSeenStore.markAllUncatSeen(uncatAmounts),
    ]);
  }

  void _handleRecurringToggle(int rid, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecurringIds.add(rid);
      } else {
        _selectedRecurringIds.remove(rid);
      }
    });
  }
  
  /// Dismisses the alert for a subscription (marks as seen).
  Future<void> _dismissSubscriptionAlert(int rid, double amount) async {
    await BudgetSeenStore.markSubscriptionSeen(rid, amount);
    setState(() {
      _recurringIsNew[rid] = false;
      _recurringShowAlert[rid] = false;
      _seenSubscriptionIds.add(rid);
      _seenSubscriptionAmounts[rid] = amount;
    });
  }

  void _handleCategoryToggle(int? catId, bool selected) {
    if (catId == null) return;
    setState(() {
      _selectedCategories[catId] = selected;
    });
  }
  
  /// Dismisses the alert for a category budget (marks as seen).
  Future<void> _dismissCategoryAlert(int catId, double amount) async {
    await BudgetSeenStore.markCategorySeen(catId, amount);
    setState(() {
      _categoryIsNew[catId] = false;
      _categoryShowAlert[catId] = false;
      _seenCategoryIds.add(catId);
      _seenCategoryAmounts[catId] = amount;
    });
  }

  void _handleUncatToggle(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedUncatKeys.add(key);
      } else {
        _selectedUncatKeys.remove(key);
      }
    });
  }
  
  /// Dismisses the alert for an uncategorized item (marks as seen).
  Future<void> _dismissUncatAlert(String key, double amount) async {
    await BudgetSeenStore.markUncatSeen(key, amount);
    setState(() {
      _uncatIsNew[key] = false;
      _uncatShowAlert[key] = false;
      _seenUncatKeys.add(key);
      _seenUncatAmounts[key] = amount;
    });
  }

  /// Applies the suggested amount for a subscription and auto-saves.
  Future<void> _applySuggestedSubscription(int rid, double suggestedAmount) async {
    setState(() {
      _recurringCurrentAmounts[rid] = suggestedAmount;
      _selectedRecurringIds.add(rid);
      _recurringHasSuggestion[rid] = false;
      _recurringShowAlert[rid] = false;
    });
    await _dismissSubscriptionAlert(rid, suggestedAmount);
    await _saveChanges(showSnackbar: false);
  }

  /// Applies the suggested amount for a category budget and auto-saves.
  Future<void> _applySuggestedCategory(int catId, double suggestedAmount) async {
    setState(() {
      _categoryCurrentAmounts[catId] = suggestedAmount;
      _selectedCategories[catId] = true;
      _categoryHasSuggestion[catId] = false;
      _categoryShowAlert[catId] = false;
    });
    await _dismissCategoryAlert(catId, suggestedAmount);
    await _saveChanges(showSnackbar: false);
  }

  /// Applies the suggested amount for an uncategorized budget and auto-saves.
  Future<void> _applySuggestedUncat(String key, double suggestedAmount) async {
    setState(() {
      _uncatCurrentAmounts[key] = suggestedAmount;
      _selectedUncatKeys.add(key);
      _uncatHasSuggestion[key] = false;
      _uncatShowAlert[key] = false;
    });
    await _dismissUncatAlert(key, suggestedAmount);
    await _saveChanges(showSnackbar: false);
  }

  /// Shows dialog to create a new manual budget.
  Future<void> _showCreateManualBudgetDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    
    final result = await showDialog<_ManualBudgetItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Budget', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Budget name',
                    hintText: 'e.g., Coffee, Entertainment',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weekly limit',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (name.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a name and amount')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, _ManualBudgetItem(
                  id: null,
                  name: name,
                  weeklyLimit: amount,
                ));
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
    });
    
    if (result != null) {
      setState(() {
        // Shift existing indices up since we're inserting at 0
        final shiftedIndices = _selectedManualBudgetIndices.map((i) => i + 1).toSet();
        _selectedManualBudgetIndices.clear();
        _selectedManualBudgetIndices.addAll(shiftedIndices);
        // Insert new budget at top and select it
        _manualBudgets.insert(0, result);
        _selectedManualBudgetIndices.add(0);
      });
      await _saveManualBudgetsToStore();
      await _saveChanges(showSnackbar: false);
    }
  }
  
  /// Saves manual budgets to the persistent store.
  Future<void> _saveManualBudgetsToStore() async {
    final manualBudgetsToStore = <ManualBudget>[];
    for (int i = 0; i < _manualBudgets.length; i++) {
      manualBudgetsToStore.add(ManualBudget(
        name: _manualBudgets[i].name,
        weeklyLimit: _manualBudgets[i].weeklyLimit,
        isSelected: _selectedManualBudgetIndices.contains(i),
      ));
    }
    await ManualBudgetStore.saveAll(manualBudgetsToStore);
  }

  /// Deletes a manual budget.
  Future<void> _deleteManualBudget(_ManualBudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Budget'),
          content: Text('Are you sure you want to delete "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      final index = _manualBudgets.indexOf(item);
      setState(() {
        _manualBudgets.remove(item);
        // Update selection indices
        _selectedManualBudgetIndices.remove(index);
        // Shift down indices that were above the removed item
        final shiftedIndices = _selectedManualBudgetIndices
            .where((i) => i > index)
            .map((i) => i - 1)
            .toSet();
        _selectedManualBudgetIndices.removeWhere((i) => i > index);
        _selectedManualBudgetIndices.addAll(shiftedIndices);
      });
      await _saveManualBudgetsToStore();
      await _saveChanges(showSnackbar: false);
    }
  }

  /// Edits a manual budget.
  Future<void> _editManualBudget(_ManualBudgetItem item) async {
    final nameController = TextEditingController(text: item.name);
    final amountController = TextEditingController(text: item.weeklyLimit.toStringAsFixed(2));
    nameController.selection = TextSelection(baseOffset: 0, extentOffset: nameController.text.length);
    
    final result = await showDialog<_ManualBudgetItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Budget', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Budget name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weekly limit',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (name.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a name and amount')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, _ManualBudgetItem(
                  id: item.id,
                  name: name,
                  weeklyLimit: amount,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
    });
    
    if (result != null) {
      final index = _manualBudgets.indexOf(item);
      if (index != -1) {
        setState(() {
          _manualBudgets[index] = result;
        });
        await _saveManualBudgetsToStore();
        await _saveChanges(showSnackbar: false);
      }
    }
  }

  BoxDecoration _rowDecoration(bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: isSelected
          ? scheme.primary.withOpacity(0.08)
          : scheme.surfaceContainerHighest.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected ? scheme.primary.withOpacity(0.35) : Colors.black12,
      ),
    );
  }

  String _getEmoji(String name) {
    return _emojiHelper?.emojiForName(name) ?? CategoryEmojiHelper.defaultEmoji;
  }

  /// Simple indicator for section headers (subscriptions/budgets dropdown).
  Widget _buildSectionChangeIndicator() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: bfmOrange,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Indicator for individual items showing new or alert for amount change.
  Widget _buildChangeIndicator({
    required bool isNew,
    required bool showAlert,
    VoidCallback? onDismiss,
  }) {
    // Show nothing if no alert to display
    if (!isNew && !showAlert) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: onDismiss,
      child: Tooltip(
        message: isNew 
            ? 'New item detected! Tap to dismiss.'
            : 'Spending has changed. Tap to dismiss.',
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: bfmOrange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isNew ? '!' : '↑',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editRecurringAmount(_SubscriptionItem item) async {
    final rid = item.recurringId;
    if (rid == null) return;
    
    final currentAmount = _recurringCurrentAmounts[rid] ?? item.weeklyAmount;
    final updated = await _showAmountEditor(
      title: item.name,
      initialValue: currentAmount.toStringAsFixed(2),
      helperText: 'Set the weekly limit for this subscription.',
    );
    if (updated == null) return;
    final newAmount = double.tryParse(updated) ?? currentAmount;
    
    // Mark as seen with the new amount and clear alerts
    await _dismissSubscriptionAlert(rid, item.weeklyAmount);
    
    setState(() {
      _recurringCurrentAmounts[rid] = newAmount;
    });
  }

  Future<void> _editCategoryAmount(_CategoryBudgetItem item) async {
    final catId = item.categoryId;
    if (catId == null) return;
    
    final currentAmount = _categoryCurrentAmounts[catId] ?? item.weeklyLimit;
    final updated = await _showAmountEditor(
      title: item.name,
      initialValue: currentAmount.toStringAsFixed(2),
      helperText: 'Set the weekly limit for this category.',
    );
    if (updated == null) return;
    final newAmount = double.tryParse(updated) ?? currentAmount;
    
    // Mark as seen with the new amount and clear alerts
    await _dismissCategoryAlert(catId, item.weeklyLimit);
    
    setState(() {
      _categoryCurrentAmounts[catId] = newAmount;
    });
  }

  Future<void> _editUncatItem(_UncategorizedItem item) async {
    final key = item.key;
    final currentAmount = _uncatCurrentAmounts[key] ?? item.weeklyAmount;
    final currentName = _uncatNameOverrides[key] ?? item.name;
    
    final result = await _showUncategorizedEditor(
      title: item.name,
      initialName: currentName,
      initialAmount: currentAmount.toStringAsFixed(2),
    );
    if (result == null) return;
    
    // Mark as seen with the new amount and clear alerts
    await _dismissUncatAlert(key, item.weeklyAmount);
    
    setState(() {
      if (result.name.isNotEmpty && result.name != item.name) {
        _uncatNameOverrides[key] = result.name;
      } else {
        _uncatNameOverrides.remove(key);
      }
      _uncatCurrentAmounts[key] = double.tryParse(result.amount) ?? currentAmount;
    });
  }

  Future<String?> _showAmountEditor({
    required String title,
    required String initialValue,
    String? helperText,
  }) async {
    final controller = TextEditingController(text: initialValue);
    // Select all text so user can immediately type
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
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
                Text(helperText, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
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
                  TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
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
    // Select all text in name field so user can immediately type
    nameController.selection = TextSelection(baseOffset: 0, extentOffset: nameController.text.length);
    
    final result = await showDialog<_UncatEditResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name this budget',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weekly limit',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, _UncatEditResult(
                name: nameController.text.trim(),
                amount: amountController.text.trim(),
              )),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
    });
    return result;
  }

  /// Calculate total budgeted for subscriptions
  double _getSubscriptionsBudgeted() {
    double total = 0.0;
    for (final rid in _selectedRecurringIds) {
      total += _recurringCurrentAmounts[rid] ?? 0.0;
    }
    return total;
  }
  
  /// Calculate total budgeted for category budgets + uncategorized + manual
  double _getCategoryBudgetsBudgeted() {
    double total = 0.0;
    for (final entry in _selectedCategories.entries) {
      if (entry.value == true && entry.key != null) {
        total += _categoryCurrentAmounts[entry.key] ?? 0.0;
      }
    }
    for (final key in _selectedUncatKeys) {
      total += _uncatCurrentAmounts[key] ?? 0.0;
    }
    // Add selected manual budgets
    for (int i = 0; i < _manualBudgets.length; i++) {
      if (_selectedManualBudgetIndices.contains(i)) {
        total += _manualBudgets[i].weeklyLimit;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsBudgeted = _getSubscriptionsBudgeted();
    final categoryBudgetsBudgeted = _getCategoryBudgetsBudgeted();
    final totalBudgeted = subscriptionsBudgeted + categoryBudgetsBudgeted;
    
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _forceSync,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total budgeted box at the top center
                    _buildTotalBudgetedBox(totalBudgeted),
                    const SizedBox(height: 16),
                    _buildDropdownCard(
                      title: 'Subscriptions',
                      icon: Icons.autorenew,
                      isExpanded: _subscriptionsExpanded,
                      onToggle: () => setState(() => _subscriptionsExpanded = !_subscriptionsExpanded),
                      hasChanges: _data!.subscriptions.any((s) => 
                          _recurringShowAlert[s.recurringId] == true),
                      budgetedAmount: subscriptionsBudgeted,
                      helpTitle: 'Subscriptions',
                      helpMessage: 'These are recurring expenses Moni detected from your transactions '
                          '(like Netflix, Spotify, gym memberships, etc.)\n\n'
                          '• Tap a subscription to include it in your budget\n'
                          '• Long press to edit the weekly amount\n'
                          '• Orange (!) means a new subscription or price change was detected\n\n'
                          'Monthly subscriptions are automatically converted to weekly amounts.',
                      children: _data!.subscriptions.isEmpty
                          ? [const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No subscriptions detected', style: TextStyle(color: Colors.black54)),
                            )]
                          : _data!.subscriptions.map((s) => _buildSubscriptionRow(s)).toList(),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownCard(
                      title: 'Budgets',
                      icon: Icons.pie_chart_outline,
                      isExpanded: _budgetsExpanded,
                      onToggle: () => setState(() => _budgetsExpanded = !_budgetsExpanded),
                      hasChanges: _data!.categoryBudgets.any((c) => 
                          _categoryShowAlert[c.categoryId] == true) ||
                          _data!.uncategorizedBudgets.any((u) => 
                          _uncatShowAlert[u.key] == true),
                      budgetedAmount: categoryBudgetsBudgeted,
                      helpTitle: 'Category Budgets',
                      helpMessage: 'These are spending categories detected from your transactions '
                          '(like groceries, transport, eating out, etc.)\n\n'
                          '• Tap a category to include it in your budget\n'
                          '• Long press to edit the weekly limit\n'
                          '• Orange (!) means new spending or a significant change was detected\n'
                          '• Orange text = uncategorized transactions grouped by name\n\n'
                          'Suggested amounts are calculated from your average weekly expenditure in each category.',
                      headerAction: _buildCreateBudgetButton(),
                      children: [
                        // Show manual budgets at the top
                        for (int i = 0; i < _manualBudgets.length; i++)
                          _buildManualBudgetRow(_manualBudgets[i], i),
                        if (_data!.categoryBudgets.isEmpty && _data!.uncategorizedBudgets.isEmpty && _manualBudgets.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No budgets detected', style: TextStyle(color: Colors.black54)),
                          )
                        else ..._buildCombinedBudgetRows(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Budget tracking card - shows spending progress per budget
                    if (_data!.trackingItems.isNotEmpty)
                      BudgetTrackingCard(items: _data!.trackingItems),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildTotalBudgetedBox(double total) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: bfmBlue.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                    color: bfmBlue,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'total weekly budgeted',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
    bool hasChanges = false,
    double? budgetedAmount,
    String? helpTitle,
    String? helpMessage,
    Widget? headerAction,
  }) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: bfmBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            if (helpMessage != null) ...[
                              const SizedBox(width: 4),
                              HelpIconTooltip(
                                title: helpTitle ?? title,
                                message: helpMessage,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        if (budgetedAmount != null && budgetedAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '\$${budgetedAmount.toStringAsFixed(2)}/wk budgeted',
                            style: TextStyle(
                              fontSize: 12,
                              color: bfmBlue.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasChanges) ...[
                    _buildSectionChangeIndicator(),
                    const SizedBox(width: 8),
                  ],
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (headerAction != null) ...[
              headerAction,
              const Divider(height: 1),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: children),
            ),
          ],
        ],
      ),
    );
  }

  /// Combines category and uncategorized budget items into a single sorted list
  List<Widget> _buildCombinedBudgetRows() {
    final combined = <_CombinedBudgetRow>[];
    
    // Add category budgets
    for (final cat in _data!.categoryBudgets) {
      combined.add(_CombinedBudgetRow(
        categoryItem: cat,
        uncatItem: null,
        txCount: cat.txCount,
        weeklyAmount: _categoryCurrentAmounts[cat.categoryId] ?? cat.weeklyLimit,
      ));
    }
    
    // Add uncategorized budgets
    for (final uncat in _data!.uncategorizedBudgets) {
      combined.add(_CombinedBudgetRow(
        categoryItem: null,
        uncatItem: uncat,
        txCount: uncat.txCount,
        weeklyAmount: _uncatCurrentAmounts[uncat.key] ?? uncat.weeklyAmount,
      ));
    }
    
    // Sort by transaction count (most used first), then by amount
    combined.sort((a, b) {
      final txCmp = b.txCount.compareTo(a.txCount);
      if (txCmp != 0) return txCmp;
      return b.weeklyAmount.compareTo(a.weeklyAmount);
    });
    
    return combined.map((row) {
      if (row.categoryItem != null) {
        return _buildBudgetRow(row.categoryItem!);
      } else {
        return _buildUncategorizedRow(row.uncatItem!);
      }
    }).toList();
  }

  Widget _buildSubscriptionRow(_SubscriptionItem item) {
    final rid = item.recurringId;
    if (rid == null) return const SizedBox.shrink();
    
    final isSelected = _selectedRecurringIds.contains(rid);
    final currentAmount = _recurringCurrentAmounts[rid] ?? item.weeklyAmount;
    final isNew = _recurringIsNew[rid] == true;
    final showAlert = _recurringShowAlert[rid] == true;
    final hasSuggestion = _recurringHasSuggestion[rid] == true;
    final detectedAmount = item.weeklyAmount;
    
    final paymentLabel = item.frequency == 'monthly'
        ? 'Monthly: \$${item.amount.toStringAsFixed(2)}'
        : 'Weekly: \$${item.amount.toStringAsFixed(2)}';
    final emoji = _getEmoji(item.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleRecurringToggle(rid, !isSelected),
        onLongPress: () => _editRecurringAmount(item),
        child: Container(
          decoration: _rowDecoration(isSelected),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        _buildChangeIndicator(
                          isNew: isNew,
                          showAlert: showAlert,
                          onDismiss: () => _dismissSubscriptionAlert(rid, detectedAmount),
                        ),
                      ],
                    ),
                    if (item.transactionName != null && item.transactionName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.transactionName!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                    const SizedBox(height: 4),
                    Text(paymentLabel, style: const TextStyle(fontSize: 12)),
                    Text(
                      'Weekly limit: \$${currentAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (hasSuggestion)
                      GestureDetector(
                        onTap: () => _applySuggestedSubscription(rid, detectedAmount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bfmOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bfmOrange.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Use \$${detectedAmount.toStringAsFixed(0)}/wk',
                            style: TextStyle(fontSize: 11, color: bfmOrange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetRow(_CategoryBudgetItem item) {
    final catId = item.categoryId;
    if (catId == null) return const SizedBox.shrink();
    
    final isSelected = _selectedCategories[catId] ?? false;
    final currentAmount = _categoryCurrentAmounts[catId] ?? item.weeklyLimit;
    final isNew = _categoryIsNew[catId] == true;
    final showAlert = _categoryShowAlert[catId] == true;
    final hasSuggestion = _categoryHasSuggestion[catId] == true;
    final detectedAmount = item.weeklyLimit;
    
    final emoji = _getEmoji(item.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleCategoryToggle(catId, !isSelected),
        onLongPress: () => _editCategoryAmount(item),
        child: Container(
          decoration: _rowDecoration(isSelected),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        _buildChangeIndicator(
                          isNew: isNew,
                          showAlert: showAlert,
                          onDismiss: () => _dismissCategoryAlert(catId, detectedAmount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekly limit: \$${currentAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (hasSuggestion)
                      GestureDetector(
                        onTap: () => _applySuggestedCategory(catId, detectedAmount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bfmOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bfmOrange.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Use \$${detectedAmount.toStringAsFixed(0)}/wk',
                            style: TextStyle(fontSize: 11, color: bfmOrange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUncategorizedRow(_UncategorizedItem item) {
    final key = item.key;
    final isSelected = _selectedUncatKeys.contains(key);
    final currentAmount = _uncatCurrentAmounts[key] ?? item.weeklyAmount;
    final isNew = _uncatIsNew[key] == true;
    final showAlert = _uncatShowAlert[key] == true;
    final hasSuggestion = _uncatHasSuggestion[key] == true;
    final detectedAmount = item.weeklyAmount;
    
    final displayName = _uncatNameOverrides[key] ?? item.name;
    final emoji = _getEmoji(displayName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleUncatToggle(key, !isSelected),
        onLongPress: () => _editUncatItem(item),
        child: Container(
          decoration: _rowDecoration(isSelected),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildChangeIndicator(
                          isNew: isNew,
                          showAlert: showAlert,
                          onDismiss: () => _dismissUncatAlert(key, detectedAmount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekly limit: \$${currentAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (hasSuggestion)
                      GestureDetector(
                        onTap: () => _applySuggestedUncat(key, detectedAmount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bfmOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bfmOrange.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Use \$${detectedAmount.toStringAsFixed(0)}/wk',
                            style: TextStyle(fontSize: 11, color: bfmOrange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the "+ Create Budget" button shown at the top of the Budgets dropdown.
  Widget _buildCreateBudgetButton() {
    return InkWell(
      onTap: _showCreateManualBudgetDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bfmBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: bfmBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create Budget',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: bfmBlue,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggles selection of a manual budget.
  void _handleManualBudgetToggle(int index) {
    setState(() {
      if (_selectedManualBudgetIndices.contains(index)) {
        _selectedManualBudgetIndices.remove(index);
      } else {
        _selectedManualBudgetIndices.add(index);
      }
    });
    // Save selection state immediately
    _saveManualBudgetsToStore();
  }

  /// Builds a row for a manually created budget (with delete button).
  Widget _buildManualBudgetRow(_ManualBudgetItem item, int index) {
    final emoji = _getEmoji(item.name);
    final isSelected = _selectedManualBudgetIndices.contains(index);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleManualBudgetToggle(index),
        onLongPress: () => _editManualBudget(item),
        child: Container(
          decoration: _rowDecoration(isSelected),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekly limit: \$${item.weeklyLimit.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                onPressed: () => _deleteManualBudget(item),
                tooltip: 'Delete budget',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class for combining and sorting budget rows
class _CombinedBudgetRow {
  final _CategoryBudgetItem? categoryItem;
  final _UncategorizedItem? uncatItem;
  final int txCount;
  final double weeklyAmount;

  const _CombinedBudgetRow({
    this.categoryItem,
    this.uncatItem,
    required this.txCount,
    required this.weeklyAmount,
  });
}

class _BudgetsData {
  final double weeklyIncome;
  final double totalBudgeted;
  final double spentOnBudgets;
  final double leftToSpend;
  final double discretionarySpent;
  final List<_SubscriptionItem> subscriptions;
  final List<_CategoryBudgetItem> categoryBudgets;
  final List<_UncategorizedItem> uncategorizedBudgets;
  final List<BudgetTrackingItem> trackingItems;

  const _BudgetsData({
    required this.weeklyIncome,
    required this.totalBudgeted,
    required this.spentOnBudgets,
    required this.leftToSpend,
    required this.discretionarySpent,
    required this.subscriptions,
    required this.categoryBudgets,
    required this.uncategorizedBudgets,
    required this.trackingItems,
  });
}

class _SubscriptionItem {
  final int? recurringId;
  final int categoryId;
  final String name;
  final String? transactionName;
  final String frequency;
  final double amount;
  final double weeklyAmount;

  const _SubscriptionItem({
    required this.recurringId,
    required this.categoryId,
    required this.name,
    this.transactionName,
    required this.frequency,
    required this.amount,
    required this.weeklyAmount,
  });
}

class _CategoryBudgetItem {
  final int? categoryId;
  final String name;
  final double weeklyLimit;
  final int txCount;

  const _CategoryBudgetItem({
    required this.categoryId,
    required this.name,
    required this.weeklyLimit,
    this.txCount = 0,
  });
}

class _UncategorizedItem {
  final String key;
  final String name;
  final String? description;
  final double weeklyAmount;
  final int txCount;

  const _UncategorizedItem({
    required this.key,
    required this.name,
    this.description,
    required this.weeklyAmount,
    required this.txCount,
  });
}

class _UncatEditResult {
  final String name;
  final String amount;
  const _UncatEditResult({required this.name, required this.amount});
}

class _ManualBudgetItem {
  final int? id;
  final String name;
  final double weeklyLimit;

  const _ManualBudgetItem({
    this.id,
    required this.name,
    required this.weeklyLimit,
  });
}
