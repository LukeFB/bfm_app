/// ---------------------------------------------------------------------------
/// File: lib/services/chat_insights_service.dart
/// Author: Generated for enhanced chatbot context
///
/// Purpose:
///   - Provides comprehensive financial insights and analysis for the chatbot
///   - Calculates actionable metrics to help users identify problems
///   - Includes explanations of what each metric means
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/budget_comparison_service.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/budget_streak_service.dart';
import 'package:bfm_app/services/savings_service.dart';

/// Comprehensive financial insights for AI chatbot context.
class ChatInsightsService {
  /// Builds a comprehensive financial context with explanations for the chatbot.
  /// This gives the AI everything it needs to proactively help users.
  static Future<String> buildComprehensiveContext() async {
    final buffer = StringBuffer();
    
    // 1. Current Financial Snapshot
    buffer.writeln(await _buildFinancialSnapshot());
    
    // 2. Spending Analysis with Problems Identified
    buffer.writeln(await _buildSpendingAnalysis());
    
    // 3. Budget Health Check
    buffer.writeln(await _buildBudgetHealthCheck());
    
    // 4. Savings Opportunities
    buffer.writeln(await _buildSavingsOpportunities());
    
    // 5. Goals Progress
    buffer.writeln(await _buildGoalsProgress());
    
    // 6. Upcoming Financial Events
    buffer.writeln(await _buildUpcomingEvents());
    
    return buffer.toString();
  }
  
  /// Current week's financial snapshot with explanations
  static Future<String> _buildFinancialSnapshot() async {
    final buffer = StringBuffer();
    buffer.writeln('=== CURRENT FINANCIAL SNAPSHOT ===');
    buffer.writeln('(Data the user sees on their dashboard)\n');
    
    try {
      final weeklyIncome = await DashboardService.weeklyIncomeLastWeek();
      final totalBudgeted = await DashboardService.getTotalBudgeted();
      final spentOnBudgets = await DashboardService.getSpentOnBudgets();
      final totalExpenses = await DashboardService.getTotalExpensesThisWeek();
      
      // Calculate left to spend using EXACT same formula as dashboard_screen.dart:
      // leftToSpend = income - budgeted - budgetOverspend - nonBudgetSpend
      final budgetOverspend = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
      final nonBudgetSpend = (totalExpenses - spentOnBudgets).clamp(0.0, double.infinity);
      final leftToSpend = weeklyIncome - totalBudgeted - budgetOverspend - nonBudgetSpend;
      final discretionaryBudget = weeklyIncome - totalBudgeted;
      
      buffer.writeln('Weekly Income: \$${weeklyIncome.toStringAsFixed(0)}');
      buffer.writeln('  → This is their estimated weekly income (from last week or recurring income)');
      buffer.writeln('');
      
      buffer.writeln('Total Budgeted: \$${totalBudgeted.toStringAsFixed(0)}');
      buffer.writeln('  → Sum of all weekly budget limits they\'ve set');
      buffer.writeln('');
      
      buffer.writeln('Spent on Budgets: \$${spentOnBudgets.toStringAsFixed(0)} of \$${totalBudgeted.toStringAsFixed(0)}');
      buffer.writeln('  → How much they\'ve spent in budgeted categories this week');
      if (spentOnBudgets > totalBudgeted && totalBudgeted > 0) {
        final overBy = spentOnBudgets - totalBudgeted;
        buffer.writeln('  ⚠️ OVER BUDGET by \$${overBy.toStringAsFixed(0)} in budgeted categories!');
      }
      buffer.writeln('');
      
      buffer.writeln('Discretionary Budget: \$${discretionaryBudget.toStringAsFixed(0)}');
      buffer.writeln('  → Income minus budgeted expenses = what\'s available for other spending');
      buffer.writeln('');
      
      if (budgetOverspend > 0) {
        buffer.writeln('Budget Overspend: \$${budgetOverspend.toStringAsFixed(0)}');
        buffer.writeln('  → Amount over budget in budgeted categories');
        buffer.writeln('');
      }
      
      if (nonBudgetSpend > 0) {
        buffer.writeln('Non-Budget Spending: \$${nonBudgetSpend.toStringAsFixed(0)}');
        buffer.writeln('  → Spending in non-budgeted categories');
        buffer.writeln('');
      }
      
      buffer.writeln('★ LEFT TO SPEND THIS WEEK: \$${leftToSpend.toStringAsFixed(0)}');
      buffer.writeln('  → This is the main number on their dashboard');
      if (leftToSpend < 0) {
        buffer.writeln('  ⚠️ NEGATIVE! User has overspent by \$${leftToSpend.abs().toStringAsFixed(0)}');
      } else if (leftToSpend < 20) {
        buffer.writeln('  ⚠️ Very tight - might need to be careful');
      }
      buffer.writeln('');
      
      buffer.writeln('Total Expenses This Week: \$${totalExpenses.toStringAsFixed(0)}');
      buffer.writeln('  → All spending combined this week (Mon to today)');
      
      // Budget streak
      final streak = await BudgetStreakService.calculateStreak();
      if (streak.streakWeeks > 0) {
        buffer.writeln('\nBudget Streak: ${streak.streakWeeks} consecutive weeks on budget!');
        buffer.writeln('  → Total saved during streak: \$${streak.totalSaved.toStringAsFixed(0)}');
      }
      
      // Profit/Loss
      buffer.writeln('\n--- PROFIT/LOSS ---');
      final profitLossWeek = await SavingsService.getProfitLossThisWeek();
      final profitLossMonth = await SavingsService.getProfitLossThisMonth();
      
      buffer.writeln('This Week: ${profitLossWeek >= 0 ? '+' : ''}\$${profitLossWeek.toStringAsFixed(0)}');
      buffer.writeln('  → ${profitLossWeek >= 0 ? 'Income exceeded expenses' : 'Spent more than earned'}');
      
      buffer.writeln('This Month: ${profitLossMonth >= 0 ? '+' : ''}\$${profitLossMonth.toStringAsFixed(0)}');
      buffer.writeln('  → ${profitLossMonth >= 0 ? 'On track to save' : 'Currently in deficit'}');
      
    } catch (e) {
      buffer.writeln('Unable to load financial snapshot: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Detailed spending analysis with problem identification
  static Future<String> _buildSpendingAnalysis() async {
    final buffer = StringBuffer();
    buffer.writeln('=== SPENDING ANALYSIS ===');
    buffer.writeln('(Categories where user might be overspending)\n');
    
    try {
      final comparisons = await BudgetComparisonService.getComparisons();
      
      if (comparisons.isEmpty) {
        buffer.writeln('No budget comparisons available yet.');
        buffer.writeln('');
        return buffer.toString();
      }
      
      // Identify problem areas
      final overBudget = comparisons.where((c) => c.isAvgOverBudget).toList();
      final onTrack = comparisons.where((c) => c.isAvgOnTrack).toList();
      final underBudget = comparisons.where((c) => c.isAvgUnderBudget).toList();
      
      if (overBudget.isNotEmpty) {
        buffer.writeln('🔴 CATEGORIES CONSISTENTLY OVER BUDGET:');
        buffer.writeln('(Average spending is >15% above their budget - these need attention)\n');
        for (final c in overBudget.take(5)) {
          final overBy = c.weeklyAvgSpend - c.budgetLimit;
          buffer.writeln('• ${c.label}:');
          buffer.writeln('  Budget: \$${c.budgetLimit.toStringAsFixed(0)}/week');
          buffer.writeln('  Avg spending: \$${c.weeklyAvgSpend.toStringAsFixed(0)}/week');
          buffer.writeln('  Over by: \$${overBy.toStringAsFixed(0)}/week (${c.avgVsBudgetPercent.toStringAsFixed(0)}% over)');
          buffer.writeln('  → Suggestion: Either increase budget or find ways to cut back');
          buffer.writeln('');
        }
      }
      
      if (underBudget.isNotEmpty) {
        buffer.writeln('💰 CATEGORIES WITH ROOM TO SPARE:');
        buffer.writeln('(Average spending is >15% below budget - could reallocate funds)\n');
        for (final c in underBudget.take(3)) {
          final underBy = c.budgetLimit - c.weeklyAvgSpend;
          buffer.writeln('• ${c.label}: Budget \$${c.budgetLimit.toStringAsFixed(0)}, Avg \$${c.weeklyAvgSpend.toStringAsFixed(0)} (saves \$${underBy.toStringAsFixed(0)}/week)');
        }
        buffer.writeln('');
      }
      
      if (onTrack.isNotEmpty) {
        buffer.writeln('✅ ON TRACK: ${onTrack.map((c) => c.label).join(', ')}');
        buffer.writeln('');
      }
      
    } catch (e) {
      buffer.writeln('Unable to analyze spending: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Budget health check
  static Future<String> _buildBudgetHealthCheck() async {
    final buffer = StringBuffer();
    buffer.writeln('=== BUDGET HEALTH CHECK ===\n');
    
    try {
      final weeklyIncome = await DashboardService.weeklyIncomeLastWeek();
      final totalBudgeted = await DashboardService.getTotalBudgeted();
      final budgets = await BudgetRepository.getAll();
      
      final budgetPercent = weeklyIncome > 0 
          ? (totalBudgeted / weeklyIncome * 100) 
          : 0.0;
      
      buffer.writeln('Budget Coverage: ${budgetPercent.toStringAsFixed(0)}% of income is budgeted');
      
      if (budgetPercent > 100) {
        buffer.writeln('⚠️ PROBLEM: Budgets exceed income by \$${(totalBudgeted - weeklyIncome).toStringAsFixed(0)}/week!');
        buffer.writeln('→ User needs to reduce budgets or increase income');
      } else if (budgetPercent > 90) {
        buffer.writeln('⚠️ WARNING: Very tight budget, only \$${(weeklyIncome - totalBudgeted).toStringAsFixed(0)} discretionary');
      } else if (budgetPercent < 50 && budgets.isNotEmpty) {
        buffer.writeln('💡 Opportunity: Only ${budgetPercent.toStringAsFixed(0)}% budgeted - consider tracking more categories');
      }
      
      if (budgets.isEmpty) {
        buffer.writeln('📋 No budgets set yet - encourage user to set up budgets');
      } else {
        buffer.writeln('\nActive budgets: ${budgets.length} categories');
      }
      
    } catch (e) {
      buffer.writeln('Unable to check budget health: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Savings opportunities identification
  static Future<String> _buildSavingsOpportunities() async {
    final buffer = StringBuffer();
    buffer.writeln('=== SAVINGS OPPORTUNITIES ===\n');
    
    try {
      // Check recurring transactions for review opportunities
      final recurring = await RecurringRepository.getAll();
      final subscriptions = recurring.where((r) => 
        r.transactionType.toLowerCase() == 'expense' && 
        r.frequency.toLowerCase() == 'monthly'
      ).toList();
      
      if (subscriptions.isNotEmpty) {
        double totalMonthly = 0;
        for (final sub in subscriptions) {
          totalMonthly += sub.amount.abs();
        }
        final weeklyEquivalent = totalMonthly / 4.33;
        
        buffer.writeln('📱 Detected ${subscriptions.length} recurring subscriptions');
        buffer.writeln('Total: \$${totalMonthly.toStringAsFixed(0)}/month (\$${weeklyEquivalent.toStringAsFixed(0)}/week)');
        buffer.writeln('→ Consider reviewing if all subscriptions are still needed');
        buffer.writeln('');
        
        // List subscriptions for review
        buffer.writeln('Subscriptions to potentially review:');
        for (final sub in subscriptions.take(5)) {
          buffer.writeln('• ${sub.description}: \$${sub.amount.abs().toStringAsFixed(0)}/month');
        }
        if (subscriptions.length > 5) {
          buffer.writeln('• ... and ${subscriptions.length - 5} more');
        }
      }
      
      // Check for categories with high spending
      final comparisons = await BudgetComparisonService.getComparisons();
      final highSpend = comparisons.where((c) => c.weeklyAvgSpend > 50).toList();
      
      if (highSpend.isNotEmpty) {
        buffer.writeln('\n💡 High-spend categories (potential savings targets):');
        for (final c in highSpend.take(3)) {
          buffer.writeln('• ${c.label}: \$${c.weeklyAvgSpend.toStringAsFixed(0)}/week avg');
        }
      }
      
    } catch (e) {
      buffer.writeln('Unable to identify savings opportunities: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Goals progress and coaching
  static Future<String> _buildGoalsProgress() async {
    final buffer = StringBuffer();
    buffer.writeln('=== SAVINGS GOALS ===\n');
    
    try {
      final goals = await GoalRepository.getAll();
      
      if (goals.isEmpty) {
        buffer.writeln('No savings goals set up yet.');
        buffer.writeln('→ Encourage user to set a savings goal');
        buffer.writeln('');
        return buffer.toString();
      }
      
      final savingsGoals = goals.where((g) => g.goalType == 'savings').toList();
      final recoveryGoals = goals.where((g) => g.goalType == 'recovery').toList();
      
      if (savingsGoals.isNotEmpty) {
        buffer.writeln('Savings Goals:');
        for (final goal in savingsGoals) {
          final progress = goal.progressFraction * 100;
          final remaining = goal.amount - goal.savedAmount;
          final weeksToGo = goal.weeklyContribution > 0 
              ? (remaining / goal.weeklyContribution).ceil() 
              : 0;
          
          buffer.writeln('• ${goal.name}:');
          buffer.writeln('  Target: \$${goal.amount.toStringAsFixed(0)}');
          buffer.writeln('  Saved: \$${goal.savedAmount.toStringAsFixed(0)} (${progress.toStringAsFixed(0)}%)');
          buffer.writeln('  Weekly contribution: \$${goal.weeklyContribution.toStringAsFixed(0)}');
          if (weeksToGo > 0) {
            buffer.writeln('  Estimated time to goal: ~$weeksToGo weeks');
          }
          if (goal.isComplete) {
            buffer.writeln('  🎉 COMPLETE!');
          }
          buffer.writeln('');
        }
      }
      
      if (recoveryGoals.isNotEmpty) {
        buffer.writeln('Recovery Goals (paying back overspending):');
        for (final goal in recoveryGoals) {
          final progress = goal.progressFraction * 100;
          buffer.writeln('• ${goal.name}: \$${goal.savedAmount.toStringAsFixed(0)} of \$${goal.amount.toStringAsFixed(0)} recovered (${progress.toStringAsFixed(0)}%)');
        }
      }
      
    } catch (e) {
      buffer.writeln('Unable to load goals: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Upcoming financial events (bills, alerts)
  static Future<String> _buildUpcomingEvents() async {
    final buffer = StringBuffer();
    buffer.writeln('=== UPCOMING PAYMENTS & ALERTS ===\n');
    
    try {
      final alerts = await DashboardService.getAlerts();
      
      if (alerts.isEmpty) {
        buffer.writeln('No upcoming alerts or bills set up.');
        buffer.writeln('');
        return buffer.toString();
      }
      
      final now = DateTime.now();
      
      for (final alert in alerts.take(5)) {
        final dueDate = alert.dueDate;
        String timing;
        bool urgent = false;
        
        if (dueDate != null) {
          final days = dueDate.difference(now).inDays;
          if (days < 0) {
            timing = 'OVERDUE';
            urgent = true;
          } else if (days == 0) {
            timing = 'Due TODAY';
            urgent = true;
          } else if (days == 1) {
            timing = 'Due TOMORROW';
            urgent = true;
          } else if (days <= 7) {
            timing = 'Due in $days days';
            urgent = true;
          } else {
            timing = 'Due in $days days';
          }
        } else {
          timing = 'No due date';
        }
        
        final urgentFlag = urgent ? '⚠️ ' : '';
        final amount = alert.amount != null ? ' (\$${alert.amount!.toStringAsFixed(0)})' : '';
        buffer.writeln('$urgentFlag${alert.title}$amount - $timing');
      }
      
      if (alerts.length > 5) {
        buffer.writeln('... and ${alerts.length - 5} more alerts');
      }
      
    } catch (e) {
      buffer.writeln('Unable to load alerts: $e');
    }
    
    buffer.writeln('');
    return buffer.toString();
  }
  
  /// Gets a summary of key problems for quick reference
  static Future<List<String>> getKeyProblems() async {
    final problems = <String>[];
    
    try {
      // Check if over budget
      final weeklyIncome = await DashboardService.weeklyIncomeLastWeek();
      final totalBudgeted = await DashboardService.getTotalBudgeted();
      final discretionarySpend = await DashboardService.discretionarySpendThisWeek();
      final discretionaryBudget = weeklyIncome - totalBudgeted;
      final leftToSpend = discretionaryBudget - discretionarySpend;
      
      if (leftToSpend < 0) {
        problems.add('Overspent this week by \$${leftToSpend.abs().toStringAsFixed(0)}');
      }
      
      if (totalBudgeted > weeklyIncome && weeklyIncome > 0) {
        problems.add('Budgets exceed income by \$${(totalBudgeted - weeklyIncome).toStringAsFixed(0)}');
      }
      
      // Check categories over budget
      final comparisons = await BudgetComparisonService.getComparisons();
      final overBudget = comparisons.where((c) => c.isAvgOverBudget).toList();
      if (overBudget.isNotEmpty) {
        problems.add('${overBudget.length} categories consistently over budget');
      }
      
      // Check goals that are behind
      final goals = await GoalRepository.getAll();
      final behindGoals = goals.where((g) => !g.isComplete && g.progressFraction < 0.5).toList();
      if (behindGoals.isNotEmpty) {
        problems.add('${behindGoals.length} goals need attention');
      }
      
    } catch (_) {
      // Silent fail - problems list is optional
    }
    
    return problems;
  }
}
