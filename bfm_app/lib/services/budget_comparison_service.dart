/// ---------------------------------------------------------------------------
/// File: lib/services/budget_comparison_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Compares this week's budget spend vs weekly average over last month
///   - Used by insights screen and chatbot context
/// ---------------------------------------------------------------------------
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/models/transaction_model.dart';

/// Comparison data for a budget item's spend this week vs weekly average.
class BudgetSpendComparison {
  final String label;
  final String? emojiHint;
  final double budgetLimit;
  final double thisWeekSpend;
  final double weeklyAvgSpend;
  final double difference;
  final double percentChange;
  final bool isCategorized;

  const BudgetSpendComparison({
    required this.label,
    this.emojiHint,
    required this.budgetLimit,
    required this.thisWeekSpend,
    required this.weeklyAvgSpend,
    required this.difference,
    required this.percentChange,
    required this.isCategorized,
  });
  
  /// Percent difference between average and budget
  double get avgVsBudgetPercent => budgetLimit > 0 
      ? ((weeklyAvgSpend - budgetLimit) / budgetLimit * 100) 
      : (weeklyAvgSpend > 0 ? 100.0 : 0.0);
  
  /// True if average spending is significantly higher than budget (consistently over)
  bool get isAvgOverBudget => avgVsBudgetPercent > 15;
  
  /// True if average spending is significantly lower than budget (consistently under)
  bool get isAvgUnderBudget => avgVsBudgetPercent < -15;
  
  /// True if average spending is roughly in line with budget
  bool get isAvgOnTrack => avgVsBudgetPercent.abs() <= 15;
}

/// A single transaction within a budget group.
class BudgetTransactionItem {
  final String description;
  final double amount;
  final String date;

  const BudgetTransactionItem({
    required this.description,
    required this.amount,
    required this.date,
  });
}

/// Budget group with this week's transactions, spending, and historical average.
class BudgetWeeklyBreakdown {
  final String label;
  final String? emojiHint;
  final double budgetLimit;
  final double thisWeekSpend;
  final double weeklyAvgSpend;
  final List<BudgetTransactionItem> transactions;
  final bool isBudgeted;

  const BudgetWeeklyBreakdown({
    required this.label,
    this.emojiHint,
    required this.budgetLimit,
    required this.thisWeekSpend,
    required this.weeklyAvgSpend,
    required this.transactions,
    required this.isBudgeted,
  });

  double get avgVsBudgetPercent => budgetLimit > 0
      ? ((weeklyAvgSpend - budgetLimit) / budgetLimit * 100)
      : (weeklyAvgSpend > 0 ? 100.0 : 0.0);

  bool get isAvgOverBudget => avgVsBudgetPercent > 15;
  bool get isAvgUnderBudget => avgVsBudgetPercent < -15;
}

/// Service for comparing budget spend against historical averages.
class BudgetComparisonService {
  /// Compares spend per budget vs weekly average over the prior month.
  /// Each budget is shown individually (not grouped) to ensure correct limits.
  /// 
  /// If [forWeekStart] is provided, compares that week's spend vs prior 4 weeks.
  /// Otherwise uses the current week (week-to-date).
  static Future<List<BudgetSpendComparison>> getComparisons({DateTime? forWeekStart}) async {
    final DateTime weekStart;
    final DateTime weekEnd;
    
    if (forWeekStart != null) {
      // Use specified week (full week)
      weekStart = DateTime(forWeekStart.year, forWeekStart.month, forWeekStart.day);
      weekEnd = weekStart.add(const Duration(days: 6));
    } else {
      // Current week (week-to-date)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      weekStart = today.subtract(Duration(days: today.weekday - 1));
      weekEnd = today;
    }
    
    // Last 4 weeks before the target week
    final monthStart = weekStart.subtract(const Duration(days: 28));
    final monthEnd = weekStart.subtract(const Duration(days: 1));
    
    final budgets = await BudgetRepository.getAll();
    if (budgets.isEmpty) return [];
    
    final categoryIds = budgets
        .where((b) => b.categoryId != null)
        .map((b) => b.categoryId!)
        .toSet();
    final categoryNames = await CategoryRepository.getNamesByIds(categoryIds);
    
    final thisWeekSpend = await TransactionRepository.sumExpensesByCategoryBetween(weekStart, weekEnd);
    final lastMonthSpend = await TransactionRepository.sumExpensesByCategoryBetween(monthStart, monthEnd);
    
    final thisWeekUncategorized = await TransactionRepository.sumExpensesByUncategorizedKeyBetween(weekStart, weekEnd);
    final lastMonthUncategorized = await TransactionRepository.sumExpensesByUncategorizedKeyBetween(monthStart, monthEnd);
    final uncategorizedNames = await TransactionRepository.getDisplayNamesForUncategorizedKeys(
      {...thisWeekUncategorized.keys, ...lastMonthUncategorized.keys}, monthStart, weekEnd,
    );
    
    // Load recurring transactions to get their descriptions as keys
    final recurringIds = budgets
        .map((b) => b.recurringTransactionId)
        .whereType<int>()
        .toSet();
    final recurringTransactions = await RecurringRepository.getByIds(recurringIds);
    final recurringKeyById = <int, String>{};
    final recurringCatById = <int, int>{};
    for (final rt in recurringTransactions) {
      if (rt.id != null && rt.description != null) {
        recurringKeyById[rt.id!] = rt.description!.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      }
      if (rt.id != null) {
        recurringCatById[rt.id!] = rt.categoryId;
      }
    }

    // Expand categoryNames to include recurring transaction categories
    final extraCatIds = recurringCatById.values.toSet().difference(categoryIds);
    if (extraCatIds.isNotEmpty) {
      categoryNames.addAll(await CategoryRepository.getNamesByIds(extraCatIds));
    }
    
    // Accumulate into indexed arrays so we can merge groups
    final cLabels = <String>[];
    final cEmojiHints = <String?>[];
    final cLimits = <double>[];
    final cThisWeeks = <double>[];
    final cWeeklyAvgs = <double>[];
    final cIsCategorized = <bool>[];
    final catToCompIdx = <int, int>{};
    final labelToCompIdx = <String, int>{};
    final seenCategoryIds = <int>{};
    final seenUncategorizedKeys = <String>{};
    final seenRecurringIds = <int>{};

    // Helper to identify uncategorized category IDs
    final uncatCatIdsComp = <int>{};
    for (final e in categoryNames.entries) {
      final l = e.value.toLowerCase();
      if (l == 'uncategorized' || l == 'uncategorised') uncatCatIdsComp.add(e.key);
    }

    for (final budget in budgets) {
      bool isUncategorizedCategory = false;
      if (budget.categoryId != null) {
        final catName = categoryNames[budget.categoryId!];
        if (catName != null) {
          final nameLower = catName.toLowerCase();
          isUncategorizedCategory = nameLower == 'uncategorized' || nameLower == 'uncategorised';
        }
      }
      
      if (budget.categoryId != null && !isUncategorizedCategory) {
        final catId = budget.categoryId!;
        if (seenCategoryIds.contains(catId)) continue;
        seenCategoryIds.add(catId);
        
        final label = categoryNames[catId] ?? 'Category';
        final idx = cLabels.length;
        cLabels.add(label);
        cEmojiHints.add(null);
        cLimits.add(budget.weeklyLimit);
        cThisWeeks.add(thisWeekSpend[catId]?.abs() ?? 0.0);
        cWeeklyAvgs.add((lastMonthSpend[catId]?.abs() ?? 0.0) / 4);
        cIsCategorized.add(true);
        catToCompIdx[catId] = idx;
        labelToCompIdx[label.toLowerCase()] = idx;
      } else if (budget.recurringTransactionId != null) {
        final recId = budget.recurringTransactionId!;
        if (seenRecurringIds.contains(recId)) continue;
        seenRecurringIds.add(recId);
        
        final key = recurringKeyById[recId];
        if (key == null || key.isEmpty) continue;

        final recCatId = budget.categoryId ?? recurringCatById[recId];
        final nonUncatCatId = (recCatId != null && !uncatCatIdsComp.contains(recCatId))
            ? recCatId : null;
        int? mergeIdx = nonUncatCatId != null ? catToCompIdx[nonUncatCatId] : null;
        if (mergeIdx == null) {
          final recLabel = _getBudgetLabel(budget, uncategorizedNames, key).toLowerCase();
          mergeIdx = labelToCompIdx[recLabel];
        }

        final recThisWeek = thisWeekUncategorized[key]?.abs() ?? 0.0;
        final recWeeklyAvg = (lastMonthUncategorized[key]?.abs() ?? 0.0) / 4;

        if (mergeIdx != null) {
          cLimits[mergeIdx] += budget.weeklyLimit;
          cThisWeeks[mergeIdx] += recThisWeek;
          cWeeklyAvgs[mergeIdx] += recWeeklyAvg;
        } else {
          final label = _getBudgetLabel(budget, uncategorizedNames, key);
          final idx = cLabels.length;
          cLabels.add(label);
          cEmojiHints.add(nonUncatCatId != null ? categoryNames[nonUncatCatId] : null);
          cLimits.add(budget.weeklyLimit);
          cThisWeeks.add(recThisWeek);
          cWeeklyAvgs.add(recWeeklyAvg);
          cIsCategorized.add(false);
          labelToCompIdx[label.toLowerCase()] = idx;
        }
      } else if (budget.uncategorizedKey != null && budget.uncategorizedKey!.isNotEmpty) {
        final key = budget.uncategorizedKey!;
        if (seenUncategorizedKeys.contains(key)) continue;
        seenUncategorizedKeys.add(key);
        
        final label = _getBudgetLabel(budget, uncategorizedNames, key);
        final mergeIdx = labelToCompIdx[label.toLowerCase()];
        final uncThisWeek = thisWeekUncategorized[key]?.abs() ?? 0.0;
        final uncWeeklyAvg = (lastMonthUncategorized[key]?.abs() ?? 0.0) / 4;

        if (mergeIdx != null) {
          cLimits[mergeIdx] += budget.weeklyLimit;
          cThisWeeks[mergeIdx] += uncThisWeek;
          cWeeklyAvgs[mergeIdx] += uncWeeklyAvg;
        } else {
          final idx = cLabels.length;
          cLabels.add(label);
          cEmojiHints.add(null);
          cLimits.add(budget.weeklyLimit);
          cThisWeeks.add(uncThisWeek);
          cWeeklyAvgs.add(uncWeeklyAvg);
          cIsCategorized.add(false);
          labelToCompIdx[label.toLowerCase()] = idx;
        }
      } else {
        continue;
      }
    }

    final comparisons = <BudgetSpendComparison>[];
    for (var i = 0; i < cLabels.length; i++) {
      final thisWeek = cThisWeeks[i];
      final weeklyAvg = cWeeklyAvgs[i];
      if (thisWeek == 0 && weeklyAvg == 0) continue;
      
      final difference = thisWeek - weeklyAvg;
      final percentChange = weeklyAvg > 0 
          ? ((thisWeek - weeklyAvg) / weeklyAvg * 100) 
          : (thisWeek > 0 ? 100.0 : 0.0);
      
      comparisons.add(BudgetSpendComparison(
        label: cLabels[i],
        emojiHint: cEmojiHints[i],
        budgetLimit: cLimits[i],
        thisWeekSpend: thisWeek,
        weeklyAvgSpend: weeklyAvg,
        difference: difference,
        percentChange: percentChange,
        isCategorized: cIsCategorized[i],
      ));
    }
    
    comparisons.sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));
    return comparisons;
  }

  /// Returns weekly transaction breakdown grouped by budget, with spending
  /// totals, individual transactions, and 4-week average per group.
  static Future<List<BudgetWeeklyBreakdown>> getWeeklyBreakdown({
    DateTime? forWeekStart,
  }) async {
    final DateTime weekStart;
    final DateTime weekEnd;

    if (forWeekStart != null) {
      weekStart = DateTime(forWeekStart.year, forWeekStart.month, forWeekStart.day);
      weekEnd = weekStart.add(const Duration(days: 6));
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      weekStart = today.subtract(Duration(days: today.weekday - 1));
      weekEnd = today;
    }

    final monthStart = weekStart.subtract(const Duration(days: 28));
    final monthEnd = weekStart.subtract(const Duration(days: 1));

    final budgets = await BudgetRepository.getAll();
    final allTxns = await TransactionRepository.getBetween(weekStart, weekEnd);
    final expenses = allTxns.where((t) => t.isExpense && !t.excluded).toList();
    if (expenses.isEmpty && budgets.isEmpty) return [];

    // Resolve category names for budgets and transactions
    final allCatIds = <int>{
      ...budgets.where((b) => b.categoryId != null).map((b) => b.categoryId!),
      ...expenses.where((t) => t.categoryId != null).map((t) => t.categoryId!),
    };
    final catNames = allCatIds.isEmpty
        ? <int, String>{}
        : await CategoryRepository.getNamesByIds(allCatIds);

    final uncatCatIds = <int>{};
    for (final e in catNames.entries) {
      final l = e.value.toLowerCase();
      if (l == 'uncategorized' || l == 'uncategorised') uncatCatIds.add(e.key);
    }

    // Historical weekly averages (4-week lookback)
    final avgByCat = await TransactionRepository.sumExpensesByCategoryBetween(
        monthStart, monthEnd);
    final avgByKey = await TransactionRepository.sumExpensesByUncategorizedKeyBetween(
        monthStart, monthEnd);

    // Recurring transaction keys for description matching
    final recIds = budgets
        .map((b) => b.recurringTransactionId)
        .whereType<int>()
        .toSet();
    final recKeyById = <int, String>{};
    final recCatById = <int, int>{};
    if (recIds.isNotEmpty) {
      final recs = await RecurringRepository.getByIds(recIds);
      for (final r in recs) {
        if (r.id != null && r.description != null) {
          recKeyById[r.id!] = _normalizeKey(r.description!);
        }
        if (r.id != null) recCatById[r.id!] = r.categoryId;
      }
      final extraCatIds = recCatById.values.toSet().difference(allCatIds);
      if (extraCatIds.isNotEmpty) {
        catNames.addAll(await CategoryRepository.getNamesByIds(extraCatIds));
      }
    }

    // Display names for uncategorized keys
    final allUncatKeys = <String>{...avgByKey.keys};
    for (final t in expenses) {
      if (t.categoryId == null || uncatCatIds.contains(t.categoryId)) {
        allUncatKeys.add(_normalizeKey(t.description));
      }
    }
    final uncatNames = allUncatKeys.isEmpty
        ? <String, String>{}
        : await TransactionRepository.getDisplayNamesForUncategorizedKeys(
            allUncatKeys, monthStart, weekEnd);

    final labels = <String>[];
    final emojiHints = <String?>[];
    final limitsList = <double>[];
    final avgsList = <double>[];
    final txnLists = <List<BudgetTransactionItem>>[];
    final spendsList = <double>[];
    final catToIdx = <int, int>{};
    final keyToIdx = <String, int>{};
    final seenCats = <int>{};
    final seenKeys = <String>{};
    final seenRecs = <int>{};

    // Build a label-to-index map so we can merge groups with the same name
    final labelToIdx = <String, int>{};

    for (final b in budgets) {
      bool isUncatCat = false;
      if (b.categoryId != null) {
        final n = catNames[b.categoryId!]?.toLowerCase() ?? '';
        isUncatCat = n == 'uncategorized' || n == 'uncategorised';
      }

      if (b.categoryId != null && !isUncatCat) {
        final cid = b.categoryId!;
        if (seenCats.contains(cid)) continue;
        seenCats.add(cid);
        final label = catNames[cid] ?? 'Category';
        final idx = labels.length;
        labels.add(label);
        emojiHints.add(null);
        limitsList.add(b.weeklyLimit);
        avgsList.add((avgByCat[cid]?.abs() ?? 0) / 4);
        txnLists.add([]);
        spendsList.add(0);
        catToIdx[cid] = idx;
        labelToIdx[label.toLowerCase()] = idx;
      } else if (b.recurringTransactionId != null) {
        final rid = b.recurringTransactionId!;
        if (seenRecs.contains(rid)) continue;
        seenRecs.add(rid);
        final k = recKeyById[rid];
        if (k == null || k.isEmpty) continue;

        // If key already has a group (e.g. from an uncategorized-key budget), merge into it
        if (seenKeys.contains(k)) {
          final existingIdx = keyToIdx[k];
          if (existingIdx != null) {
            limitsList[existingIdx] += b.weeklyLimit;
          }
          continue;
        }
        seenKeys.add(k);

        // Check if this recurring payment's category already has a group
        final recCatId = b.categoryId ?? recCatById[rid];
        final nonUncatCatId = (recCatId != null && !uncatCatIds.contains(recCatId))
            ? recCatId : null;
        int? mergeIdx = nonUncatCatId != null ? catToIdx[nonUncatCatId] : null;

        // Also check if the label matches an existing group
        if (mergeIdx == null) {
          final recLabel = _getBudgetLabel(b, uncatNames, k).toLowerCase();
          mergeIdx = labelToIdx[recLabel];
        }

        if (mergeIdx != null) {
          limitsList[mergeIdx] += b.weeklyLimit;
          avgsList[mergeIdx] += (avgByKey[k]?.abs() ?? 0) / 4;
          keyToIdx[k] = mergeIdx;
        } else {
          final label = _getBudgetLabel(b, uncatNames, k);
          final idx = labels.length;
          labels.add(label);
          emojiHints.add(nonUncatCatId != null ? catNames[nonUncatCatId] : null);
          limitsList.add(b.weeklyLimit);
          avgsList.add((avgByKey[k]?.abs() ?? 0) / 4);
          txnLists.add([]);
          spendsList.add(0);
          keyToIdx[k] = idx;
          labelToIdx[label.toLowerCase()] = idx;
        }
      } else if (b.uncategorizedKey != null && b.uncategorizedKey!.isNotEmpty) {
        final k = b.uncategorizedKey!;
        // If key already has a group (e.g. from a recurring budget), merge into it
        if (seenKeys.contains(k)) {
          final existingIdx = keyToIdx[k];
          if (existingIdx != null) {
            limitsList[existingIdx] += b.weeklyLimit;
          }
          continue;
        }
        seenKeys.add(k);
        final label = _getBudgetLabel(b, uncatNames, k);
        // Check if the label matches an existing group
        final mergeIdx = labelToIdx[label.toLowerCase()];
        if (mergeIdx != null) {
          limitsList[mergeIdx] += b.weeklyLimit;
          avgsList[mergeIdx] += (avgByKey[k]?.abs() ?? 0) / 4;
          keyToIdx[k] = mergeIdx;
        } else {
          final idx = labels.length;
          labels.add(label);
          emojiHints.add(null);
          limitsList.add(b.weeklyLimit);
          avgsList.add((avgByKey[k]?.abs() ?? 0) / 4);
          txnLists.add([]);
          spendsList.add(0);
          keyToIdx[k] = idx;
          labelToIdx[label.toLowerCase()] = idx;
        }
      }
    }

    // Assign each expense transaction to a budget group or "other"
    final otherMap = <String, ({double spend, List<BudgetTransactionItem> txns})>{};

    for (final t in expenses) {
      final item = BudgetTransactionItem(
        description: t.description,
        amount: t.amount.abs(),
        date: t.date,
      );

      int? idx;
      if (t.categoryId != null && !uncatCatIds.contains(t.categoryId)) {
        idx = catToIdx[t.categoryId!];
      }
      idx ??= keyToIdx[_normalizeKey(t.description)];

      if (idx != null) {
        txnLists[idx].add(item);
        spendsList[idx] += item.amount;
      } else {
        final label = (t.categoryId != null && !uncatCatIds.contains(t.categoryId))
            ? (catNames[t.categoryId!] ?? 'Other')
            : 'Other';
        final existing = otherMap[label];
        if (existing != null) {
          existing.txns.add(item);
          otherMap[label] = (spend: existing.spend + item.amount, txns: existing.txns);
        } else {
          otherMap[label] = (spend: item.amount, txns: [item]);
        }
      }
    }

    // Build result
    final result = <BudgetWeeklyBreakdown>[];
    for (var i = 0; i < labels.length; i++) {
      if (spendsList[i] == 0 && avgsList[i] == 0 && txnLists[i].isEmpty) continue;
      result.add(BudgetWeeklyBreakdown(
        label: labels[i],
        emojiHint: emojiHints[i],
        budgetLimit: limitsList[i],
        thisWeekSpend: spendsList[i],
        weeklyAvgSpend: avgsList[i],
        transactions: txnLists[i],
        isBudgeted: true,
      ));
    }

    for (final e in otherMap.entries) {
      result.add(BudgetWeeklyBreakdown(
        label: e.key,
        budgetLimit: 0,
        thisWeekSpend: e.value.spend,
        weeklyAvgSpend: 0,
        transactions: e.value.txns,
        isBudgeted: false,
      ));
    }

    result.sort((a, b) {
      if (a.isBudgeted != b.isBudgeted) return a.isBudgeted ? -1 : 1;
      return b.thisWeekSpend.compareTo(a.thisWeekSpend);
    });

    return result;
  }

  static String _normalizeKey(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Gets the display label for a budget, preferring custom label over transaction name.
  static String _getBudgetLabel(
    dynamic budget,
    Map<String, String> uncategorizedNames,
    String key,
  ) {
    // Use budget's custom label if set and not generic
    final customLabel = (budget.label as String?)?.trim() ?? '';
    if (customLabel.isNotEmpty) {
      final labelLower = customLabel.toLowerCase();
      if (labelLower != 'uncategorized' && 
          labelLower != 'uncategorised' &&
          labelLower != 'other transaction') {
        return customLabel;
      }
    }
    // Fall back to transaction name from uncategorizedNames
    final transactionName = uncategorizedNames[key];
    if (transactionName != null && transactionName.trim().isNotEmpty) {
      final nameLower = transactionName.trim().toLowerCase();
      if (nameLower != 'uncategorized' && nameLower != 'uncategorised') {
        return transactionName.trim();
      }
    }
    // Final fallback: title case the key
    return _titleCase(key);
  }
  
  /// Builds a context string for the AI chatbot describing spend comparisons.
  static Future<String> buildChatbotContext({DateTime? forWeekStart}) async {
    final comparisons = await getComparisons(forWeekStart: forWeekStart);
    // Filter to only categorized budgets - uncategorized items aren't actionable
    final categorizedComparisons = comparisons.where((c) => c.isCategorized).toList();
    if (categorizedComparisons.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('Weekly budget vs last month\'s weekly average:');
    buffer.writeln('- "Avg" = weekly average spending calculated from last 4 weeks');
    buffer.writeln('- "Budget" = the user\'s weekly budget limit for that category');
    buffer.writeln('The comparison shows if the user\'s TYPICAL spending (avg) fits their budget:');
    buffer.writeln('- "On track" = avg is at or under budget');
    buffer.writeln('- "Normal variance" = avg is slightly over budget but within 15% (acceptable)');
    buffer.writeln('- "Over budget" = avg is >15% above budget (user consistently overspends here)');
    buffer.writeln('- "Under budget" = avg is >15% below budget (user has room to spare)');
    buffer.writeln('');
    
    for (final c in categorizedComparisons.take(10)) {
      final status = c.isAvgOverBudget 
          ? 'over budget (avg ${c.avgVsBudgetPercent.toStringAsFixed(0)}% above)'
          : c.weeklyAvgSpend > c.budgetLimit
              ? 'normal variance (slightly over but ok)'
              : c.isAvgUnderBudget 
                  ? 'under budget'
                  : 'on track';
      
      buffer.writeln(
        '- ${c.label}: avg \$${c.weeklyAvgSpend.toStringAsFixed(0)}, '
        'budget \$${c.budgetLimit.toStringAsFixed(0)} - $status'
      );
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  static String _titleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
