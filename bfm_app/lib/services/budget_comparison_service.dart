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
import 'package:bfm_app/repositories/transaction_repository.dart';

/// Comparison data for a budget item's spend this week vs weekly average.
class BudgetSpendComparison {
  final String label;
  final double budgetLimit;
  final double thisWeekSpend;
  final double weeklyAvgSpend; // Weekly average over last 4 weeks
  final double difference;
  final double percentChange;
  final bool isCategorized;
  
  const BudgetSpendComparison({
    required this.label,
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

/// Service for comparing budget spend against historical averages.
class BudgetComparisonService {
  /// Compares spend per budget vs weekly average over the prior month.
  /// Groups multiple budgets under the same category to avoid double-counting.
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
    
    // Group budgets by category to avoid double-counting
    final categoryBudgets = <int, double>{};
    final uncategorizedBudgets = <String, double>{};
    
    for (final budget in budgets) {
      if (budget.categoryId != null) {
        categoryBudgets[budget.categoryId!] = 
            (categoryBudgets[budget.categoryId!] ?? 0.0) + budget.weeklyLimit;
      } else if (budget.uncategorizedKey != null && budget.uncategorizedKey!.isNotEmpty) {
        uncategorizedBudgets[budget.uncategorizedKey!] = 
            (uncategorizedBudgets[budget.uncategorizedKey!] ?? 0.0) + budget.weeklyLimit;
      }
    }
    
    final comparisons = <BudgetSpendComparison>[];
    
    // Process categorized budgets (grouped by category)
    for (final entry in categoryBudgets.entries) {
      final catId = entry.key;
      final totalBudget = entry.value;
      
      final catName = categoryNames[catId];
      if (catName == null) continue;
      final nameLower = catName.toLowerCase();
      if (nameLower == 'uncategorized' || nameLower == 'uncategorised') continue;
      
      final thisWeek = thisWeekSpend[catId]?.abs() ?? 0.0;
      // Weekly average = total over 4 weeks / 4
      final weeklyAvg = (lastMonthSpend[catId]?.abs() ?? 0.0) / 4;
      
      if (thisWeek == 0 && weeklyAvg == 0) continue;
      
      final difference = thisWeek - weeklyAvg;
      final percentChange = weeklyAvg > 0 
          ? ((thisWeek - weeklyAvg) / weeklyAvg * 100) 
          : (thisWeek > 0 ? 100.0 : 0.0);
      
      comparisons.add(BudgetSpendComparison(
        label: catName,
        budgetLimit: totalBudget,
        thisWeekSpend: thisWeek,
        weeklyAvgSpend: weeklyAvg,
        difference: difference,
        percentChange: percentChange,
        isCategorized: true,
      ));
    }
    
    // Process uncategorized budgets (grouped by key)
    for (final entry in uncategorizedBudgets.entries) {
      final key = entry.key;
      final totalBudget = entry.value;
      
      final label = uncategorizedNames[key] ?? _titleCase(key);
      
      final thisWeek = thisWeekUncategorized[key]?.abs() ?? 0.0;
      final weeklyAvg = (lastMonthUncategorized[key]?.abs() ?? 0.0) / 4;
      
      if (thisWeek == 0 && weeklyAvg == 0) continue;
      
      final difference = thisWeek - weeklyAvg;
      final percentChange = weeklyAvg > 0 
          ? ((thisWeek - weeklyAvg) / weeklyAvg * 100) 
          : (thisWeek > 0 ? 100.0 : 0.0);
      
      comparisons.add(BudgetSpendComparison(
        label: label,
        budgetLimit: totalBudget,
        thisWeekSpend: thisWeek,
        weeklyAvgSpend: weeklyAvg,
        difference: difference,
        percentChange: percentChange,
        isCategorized: false,
      ));
    }
    
    comparisons.sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));
    return comparisons;
  }
  
  /// Builds a context string for the AI chatbot describing spend comparisons.
  static Future<String> buildChatbotContext({DateTime? forWeekStart}) async {
    final comparisons = await getComparisons(forWeekStart: forWeekStart);
    if (comparisons.isEmpty) return '';
    
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
    
    for (final c in comparisons.take(10)) {
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
