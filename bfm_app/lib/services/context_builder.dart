// ---------------------------------------------------------------------------
// File: lib/services/context_builder.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - `chat_screen.dart` before sending backend chat requests.
//
// Purpose:
//   - Builds the PRIVATE CONTEXT block (user financial data, goals, budgets,
//     alerts, etc.) injected before the chat turns.
//   - Each value is described once with a clear explanation of how it was
//     computed so the AI knows exactly what it's looking at.
//
// Inputs:
//   - Recent UI turns plus boolean flags for which data sections to include.
//
// Outputs:
//   - A single multi-line string sent to the backend with the message.
// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:bfm_app/services/app_savings_store.dart';
import 'package:bfm_app/services/budget_buffer_store.dart';
import 'package:bfm_app/services/budget_comparison_service.dart';
import 'package:bfm_app/services/budget_streak_service.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/dashboard_service.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/services/savings_service.dart';

/// Produces the assistant's private context using stored chat + DB data.
///
/// Every section appears exactly once. Each value includes a brief
/// "how this was calculated" note so the AI can quote numbers confidently.
class ContextBuilder {
  static Future<String> build({
    required List<Map<String, String>> recentTurns,
  }) async {
    final buf = StringBuffer();
    buf.writeln('PRIVATE CONTEXT — data only, for assistant reference.');
    buf.writeln('All dollar amounts are NZD. Week = Monday to today unless noted.\n');

    final now = DateTime.now();
    buf.writeln('today: ${_longDate(now)} (${now.toIso8601String()})');

    // ── User profile ───────────────────────────────────────────────────────
    final profile = await _profileSection();
    if (profile.isNotEmpty) {
      buf.writeln('\n--- USER PROFILE ---');
      buf.writeln(profile);
    }

    // ── Conversation summary ───────────────────────────────────────────────
    final convo = await _conversationSection();
    if (convo.isNotEmpty) {
      buf.writeln('\n--- CONVERSATION HISTORY (summary of past chats) ---');
      buf.writeln(convo);
    }

    // ── Financial snapshot ─────────────────────────────────────────────────
    buf.writeln('\n--- THIS WEEK\'S FINANCIAL SNAPSHOT ---');
    buf.writeln('(These are the numbers shown on the user\'s dashboard)');
    await _snapshotSection(buf);

    // ── Budgets ────────────────────────────────────────────────────────────
    buf.writeln('\n--- BUDGETS ---');
    buf.writeln('(Weekly spending limits the user has set. Each budget tracks a');
    buf.writeln('category or a specific recurring transaction.)');
    await _budgetSection(buf);

    // ── App savings ──────────────────────────────────────────────────────
    buf.writeln('\n--- APP SAVINGS ---');
    buf.writeln('(Cumulative money saved by staying under budget each week.)');
    await _appSavingsSection(buf);

    // ── Buxly buffers ─────────────────────────────────────────────────────
    buf.writeln('\n--- BUXLY BUFFERS ---');
    buf.writeln('(Money put aside from weekly budget surpluses as a safety net for budgets.)');
    await _budgetBufferSection(buf);

    // ── Savings goals ──────────────────────────────────────────────────────
    buf.writeln('\n--- SAVINGS GOALS ---');
    buf.writeln('(Targets the user is saving towards with weekly contributions.)');
    await _goalsSection(buf);

    // ── Alerts ─────────────────────────────────────────────────────────────
    buf.writeln('\n--- ALERTS ---');
    buf.writeln('(Reminders the user set for upcoming bills or payments.)');
    await _alertsSection(buf);

    // ── Recurring subscriptions ────────────────────────────────────────────
    buf.writeln('\n--- RECURRING SUBSCRIPTIONS / BILLS ---');
    buf.writeln('(Detected repeating transactions from their bank data.)');
    await _recurringSection(buf);

    // ── Referral services ──────────────────────────────────────────────────
    buf.writeln('\n--- REFERRAL SERVICES ---');
    buf.writeln('(Community support services available to the user.)');
    await _referralSection(buf);

    // ── Campus events ──────────────────────────────────────────────────────
    await _eventsSection(buf);

    buf.writeln('\nEND CONTEXT.');
    return buf.toString();
  }

  // =========================================================================
  //  Section builders — each data point appears exactly once
  // =========================================================================

  /// Onboarding profile answers (income frequency, primary goal, etc.)
  static Future<String> _profileSection() async {
    final OnboardingResponse? response = await OnboardingStore().getResponse();
    if (response == null || !response.hasAnswers) return '';
    final map = response.toDisplayMap();
    if (map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  /// Compressed bullet-point summary of past conversations.
  static Future<String> _conversationSection() async {
    final all = await ChatStorage().loadAllMessages();
    if (all.isEmpty) return '';

    const kKeepTail = 8;
    final head = (all.length > kKeepTail)
        ? all.sublist(0, all.length - kKeepTail)
        : const <ChatMessage>[];
    final tail = all.length > kKeepTail
        ? all.sublist(all.length - kKeepTail)
        : all;

    final bullets = <String>[];
    for (final m in head) {
      if (m.role == ChatRole.user) {
        bullets.add('• ${_clip(m.content, 140)}');
        if (bullets.length >= 5) break;
      }
    }
    for (final m in tail) {
      if (m.role == ChatRole.user) {
        bullets.add('• recent: ${_clip(m.content, 140)}');
        if (bullets.length >= 10) break;
      }
    }
    return bullets.join('\n');
  }

  /// Core dashboard numbers — each computed once, described clearly.
  static Future<void> _snapshotSection(StringBuffer buf) async {
    try {
      final weeklyIncome = await DashboardService.weeklyIncomeLastWeek();
      final totalBudgeted = await DashboardService.getTotalBudgeted();
      final goalContributions = await DashboardService.getGoalBudgetTotal();
      final spentOnBudgets = await DashboardService.getSpentOnBudgets();
      final totalExpenses = await DashboardService.getTotalExpensesThisWeek();

      // Combine non-goal budgets and goal budgets into unified totals so that
      // goal spending isn't double-counted (once as a reservation and again
      // inside nonBudgetSpend). This matches the insights formula.
      final allBudgeted = totalBudgeted + goalContributions;
      final allBudgetSpend = spentOnBudgets + goalContributions;
      final budgetOverspend =
          (allBudgetSpend - allBudgeted).clamp(0.0, double.infinity);
      final nonBudgetSpend =
          (totalExpenses - allBudgetSpend).clamp(0.0, double.infinity);
      final leftToSpend =
          weeklyIncome - allBudgeted - budgetOverspend - nonBudgetSpend;

      buf.writeln('');
      buf.writeln('Weekly Income: \$${weeklyIncome.toStringAsFixed(0)}');
      buf.writeln('  How: Last week\'s income transactions (or 4-week average if income is irregular).');
      buf.writeln('');

      buf.writeln('Total Budgeted: \$${totalBudgeted.toStringAsFixed(0)}/week');
      buf.writeln('  How: Sum of all active budget weekly limits (excludes goal contributions).');
      buf.writeln('');

      buf.writeln('Goal Contributions: \$${goalContributions.toStringAsFixed(0)}/week');
      buf.writeln('  How: Sum of weekly contribution amounts across all savings goals.');
      buf.writeln('');

      buf.writeln('Spent on Budgets: \$${spentOnBudgets.toStringAsFixed(0)}');
      buf.writeln('  How: Actual spend this week (Mon-today) in budgeted categories only.');
      if (budgetOverspend > 0) {
        buf.writeln('  ⚠ Over budget by \$${budgetOverspend.toStringAsFixed(0)} in budgeted categories.');
      }
      buf.writeln('');

      buf.writeln('Non-Budget Spending: \$${nonBudgetSpend.toStringAsFixed(0)}');
      buf.writeln('  How: Total expenses minus budgeted spend = spending in unbudgeted categories.');
      buf.writeln('');

      buf.writeln('Total Expenses: \$${totalExpenses.toStringAsFixed(0)}');
      buf.writeln('  How: All expense transactions Mon-today (all categories combined).');
      buf.writeln('');

      buf.writeln('★ Left to Spend: \$${leftToSpend.toStringAsFixed(0)}');
      buf.writeln('  How: Income - Budgeted - Goals - Budget Overspend - Non-Budget Spend.');
      buf.writeln('  This is the main number on their dashboard.');
      if (leftToSpend < 0) {
        buf.writeln('  ⚠ NEGATIVE — user has overspent by \$${leftToSpend.abs().toStringAsFixed(0)} this week.');
      } else if (leftToSpend < 20) {
        buf.writeln('  ⚠ Very tight — user should be careful with remaining spend.');
      }
      buf.writeln('');

      // Profit / loss
      final plWeek = await SavingsService.getProfitLossThisWeek();
      final plMonth = await SavingsService.getProfitLossThisMonth();
      buf.writeln('Profit/Loss This Week: ${_signedDollar(plWeek)}');
      buf.writeln('  How: Income minus expenses Mon-today.');
      buf.writeln('Profit/Loss This Month: ${_signedDollar(plMonth)}');
      buf.writeln('  How: Income minus expenses from the 1st of the month to today.');
      buf.writeln('');

      // Streak
      final streak = await BudgetStreakService.calculateStreak();
      if (streak.streakWeeks > 0) {
        buf.writeln('Budget Streak: ${streak.streakWeeks} consecutive weeks on budget.');
        buf.writeln('  How: Counts backwards through weekly reports — each week with positive');
        buf.writeln('  left-to-spend counts. Total saved during streak: \$${streak.totalSaved.toStringAsFixed(0)}.');
      } else {
        buf.writeln('Budget Streak: 0 weeks (no current streak).');
      }
    } catch (e) {
      buf.writeln('Unable to load financial snapshot: $e');
    }
  }

  /// Budget list with this week's spend and 4-week average — one combined view.
  static Future<void> _budgetSection(StringBuffer buf) async {
    try {
      final comparisons = await BudgetComparisonService.getComparisons();
      if (comparisons.isEmpty) {
        buf.writeln('No budgets set up yet.');
        return;
      }

      buf.writeln('');
      buf.writeln('Each row: Name | Limit/week | Spent this week | 4-week avg | Status');
      buf.writeln('"4-week avg" = average weekly spend for last 4 completed weeks.');
      buf.writeln('"Status" compares the 4-week avg to the budget limit:');
      buf.writeln('  on track = avg within 15% of limit');
      buf.writeln('  over budget = avg >15% above limit (consistent overspending)');
      buf.writeln('  under budget = avg >15% below limit (room to spare)');
      buf.writeln('');

      for (final c in comparisons) {
        final status = c.isAvgOverBudget
            ? 'OVER BUDGET (avg ${c.avgVsBudgetPercent.toStringAsFixed(0)}% above limit)'
            : c.isAvgUnderBudget
                ? 'under budget'
                : 'on track';
        buf.writeln(
          '• ${c.label}: \$${c.budgetLimit.toStringAsFixed(0)}/wk limit | '
          '\$${c.thisWeekSpend.toStringAsFixed(0)} this week | '
          'avg \$${c.weeklyAvgSpend.toStringAsFixed(0)}/wk | '
          '$status',
        );
      }
    } catch (e) {
      buf.writeln('Unable to load budgets: $e');
    }
  }

  /// App savings — cumulative money saved by staying under budget.
  static Future<void> _appSavingsSection(StringBuffer buf) async {
    try {
      final total = await AppSavingsStore.getTotal();
      buf.writeln('');
      buf.writeln('App Savings Total: \$${total.toStringAsFixed(0)}');
      buf.writeln('  How: Each week the user finishes under budget, the leftover is added here.');
      buf.writeln('  If the user goes over budget, app savings are automatically used to cover');
      buf.writeln('  the deficit before a recovery goal is created. This reduces the app savings.');
      if (total <= 0) {
        buf.writeln('  Currently empty — user has not accumulated savings yet.');
      }
    } catch (e) {
      buf.writeln('Unable to load app savings: $e');
    }
  }

  /// Per-budget buffer — money set aside from weekly surpluses per budget.
  static Future<void> _budgetBufferSection(StringBuffer buf) async {
    try {
      final balances = await BudgetBufferStore.getAll();
      final lastContribs = await BudgetBufferStore.getLastContributions();

      buf.writeln('');
      buf.writeln('How Buxly Buffers work:');
      buf.writeln('  Each budget has its own buffer. Weekly surpluses (budget limit minus spend)');
      buf.writeln('  are added to that budget\'s buffer. If overspent, the buffer absorbs it.');
      buf.writeln('  If a budget\'s buffer goes negative, app savings cover that individual shortfall.');
      buf.writeln('  This is a safety net — if there\'s a big payment on a budget but');
      buf.writeln('  that budget\'s buffer covers it, the user is still on track.');
      buf.writeln('');

      if (balances.isEmpty) {
        buf.writeln('No buffer built up yet — it grows as budgets have surpluses each week.');
        return;
      }

      for (final entry in balances.entries) {
        final lastContrib = lastContribs[entry.key];
        final contribStr = lastContrib != null
            ? ' (last week: ${lastContrib >= 0 ? '+' : ''}\$${lastContrib.toStringAsFixed(0)})'
            : '';
        buf.writeln('• ${entry.key}: \$${entry.value.toStringAsFixed(0)} buffered$contribStr');
      }
    } catch (e) {
      buf.writeln('Unable to load Buxly Buffers: $e');
    }
  }

  /// Savings and recovery goals with target, saved, weekly, and ETA.
  static Future<void> _goalsSection(StringBuffer buf) async {
    try {
      final goals = await GoalRepository.getAll();
      if (goals.isEmpty) {
        buf.writeln('No savings goals set up yet.');
        return;
      }

      final savingsGoals = goals.where((g) => !g.isRecoveryGoal).toList();
      final recoveryGoals = goals.where((g) => g.isRecoveryGoal).toList();

      if (savingsGoals.isNotEmpty) {
        buf.writeln('');
        buf.writeln('Savings Goals (contributed to at end of week from leftover money):');
        for (final goal in savingsGoals) {
          _writeGoalLine(buf, goal);
        }
      }

      if (recoveryGoals.isNotEmpty) {
        buf.writeln('');
        buf.writeln('Recovery Goals (created when user overspends):');
        buf.writeln('  How recovery works:');
        buf.writeln('  - If the user finishes a week with negative left-to-spend, they are over budget.');
        buf.writeln('  - App savings are used first to cover the deficit (reduces app savings balance).');
        buf.writeln('  - Any remaining deficit creates or adds to a recovery goal.');
        buf.writeln('  - The recovery goal has a target (total deficit) and weekly payment plan.');
        buf.writeln('  - Each week with positive left-to-spend, the recovery goal is contributed to');
        buf.writeln('    FIRST before savings goals, reducing the outstanding balance.');
        buf.writeln('  - Once fully paid back, the recovery goal is complete.');
        buf.writeln('');
        for (final goal in recoveryGoals) {
          _writeGoalLine(buf, goal);
          if (goal.originalDeficit != null) {
            buf.writeln('  Original deficit: \$${goal.originalDeficit!.toStringAsFixed(0)}');
          }
          if (goal.recoveryWeeks != null) {
            buf.writeln('  Payback plan: ${goal.recoveryWeeks} weeks');
          }
        }
      }
    } catch (e) {
      buf.writeln('Unable to load goals: $e');
    }
  }

  static void _writeGoalLine(StringBuffer buf, GoalModel goal) {
    final progress = goal.progressFraction * 100;
    final remaining = goal.amount - goal.savedAmount;
    final weeksToGo = goal.weeklyContribution > 0
        ? (remaining / goal.weeklyContribution).ceil()
        : 0;

    buf.writeln('• ${goal.name}:');
    buf.writeln('  Target: \$${goal.amount.toStringAsFixed(0)}');
    buf.writeln('  Saved/paid back: \$${goal.savedAmount.toStringAsFixed(0)} (${progress.toStringAsFixed(0)}%)');
    buf.writeln('  Weekly contribution: \$${goal.weeklyContribution.toStringAsFixed(0)}');
    if (goal.isComplete) {
      buf.writeln('  ✓ COMPLETE');
    } else if (weeksToGo > 0) {
      buf.writeln('  Remaining: \$${remaining.toStringAsFixed(0)} (~$weeksToGo weeks)');
    }
  }

  /// Active alerts with due dates and urgency.
  static Future<void> _alertsSection(StringBuffer buf) async {
    try {
      final alerts = await DashboardService.getAlerts();
      if (alerts.isEmpty) {
        buf.writeln('No active alerts.');
        return;
      }

      buf.writeln('');
      final now = DateTime.now();
      for (final alert in alerts) {
        final dueDate = alert.dueDate;
        String timing;
        bool urgent = false;

        if (dueDate != null) {
          final days = dueDate.difference(now).inDays;
          if (days < 0) {
            timing = 'OVERDUE';
            urgent = true;
          } else if (days == 0) {
            timing = 'due TODAY';
            urgent = true;
          } else if (days == 1) {
            timing = 'due tomorrow';
            urgent = true;
          } else if (days <= 7) {
            timing = 'due in $days days';
            urgent = true;
          } else {
            timing = 'due in $days days';
          }
        } else {
          timing = 'no due date set';
        }

        final amount = alert.amount != null
            ? ' | \$${alert.amount!.toStringAsFixed(0)}'
            : '';
        final flag = urgent ? '⚠ ' : '';
        final linked = alert.recurringTransactionId != null
            ? ' (linked to subscription)'
            : '';
        buf.writeln('$flag• ${alert.title}$amount | $timing$linked');
      }
    } catch (e) {
      buf.writeln('Unable to load alerts: $e');
    }
  }

  /// Recurring subscriptions with amounts, frequency, next due, cancel links.
  static Future<void> _recurringSection(StringBuffer buf) async {
    try {
      final recurring = await RecurringRepository.getAll();
      if (recurring.isEmpty) {
        buf.writeln('No recurring payments detected.');
        return;
      }

      double totalMonthly = 0;
      final monthly = recurring.where(
        (r) => r.transactionType.toLowerCase() == 'expense' &&
            r.frequency.toLowerCase() == 'monthly',
      );
      for (final sub in monthly) {
        totalMonthly += sub.amount.abs();
      }

      buf.writeln('');
      if (totalMonthly > 0) {
        buf.writeln('Total monthly subscriptions: \$${totalMonthly.toStringAsFixed(0)}/month '
            '(\$${(totalMonthly / 4.33).toStringAsFixed(0)}/week equivalent).');
        buf.writeln('');
      }

      for (final r in recurring) {
        final desc = r.description ?? 'Recurring payment';
        final amount = '\$${r.amount.abs().toStringAsFixed(r.amount.abs() >= 100 ? 0 : 2)}';
        final cancelUrl = _cancellationUrl(desc);
        final pieces = <String>[
          desc,
          amount,
          r.frequency,
          'next due ${r.nextDueDate}',
          r.transactionType,
          if (cancelUrl != null) 'CANCEL: $cancelUrl',
        ];
        buf.writeln('• ${pieces.join(' | ')}');
      }
    } catch (e) {
      buf.writeln('Unable to load recurring: $e');
    }
  }

  /// Referral services from the local DB.
  static Future<void> _referralSection(StringBuffer buf) async {
    try {
      final db = await AppDatabase.instance.database;
      final referrals = await db.query(
        'referrals',
        columns: ['organisation_name', 'services', 'website'],
        where: 'is_active = 1',
        orderBy: 'updated_at DESC',
        limit: 20,
      );

      if (referrals.isEmpty) {
        buf.writeln('No referral services available.');
        return;
      }

      buf.writeln('');
      for (final r in referrals) {
        final name = (r['organisation_name'] ?? '').toString().trim();
        final services = _clip((r['services'] ?? '').toString().trim(), 90);
        final website = (r['website'] ?? '').toString().trim();
        final svc = services.isEmpty ? 'general support' : services;
        final url = website.isNotEmpty
            ? website.replaceFirst(RegExp(r'^https?://'), '')
            : '';
        if (url.isNotEmpty) {
          buf.writeln('• $svc — $url${name.isNotEmpty ? ' ($name)' : ''}');
        } else {
          buf.writeln('• $svc${name.isNotEmpty ? ' — $name' : ''}');
        }
      }
    } catch (e) {
      buf.writeln('Unable to load referrals: $e');
    }
  }

  /// Upcoming campus events.
  static Future<void> _eventsSection(StringBuffer buf) async {
    try {
      final db = await AppDatabase.instance.database;
      final events = await db.query(
        'events',
        columns: ['title', 'end_date'],
        where: 'end_date IS NOT NULL AND end_date >= ?',
        whereArgs: [DateTime.now().toIso8601String()],
        orderBy: 'end_date ASC',
        limit: 5,
      );

      if (events.isEmpty) return;

      buf.writeln('\n--- CAMPUS EVENTS ---');
      for (final e in events) {
        final title = (e['title'] ?? 'Event').toString();
        final end = e['end_date']?.toString() ?? '';
        final endFmt = end.length >= 10 ? end.substring(0, 10) : end;
        buf.writeln('• $title${endFmt.isNotEmpty ? ' (ends $endFmt)' : ''}');
      }
    } catch (_) {
      // Events are optional — silent fail
    }
  }

  // =========================================================================
  //  Helpers
  // =========================================================================

  static String _clip(String s, int max) {
    final t = s.trim().replaceAll('\n', ' ');
    return (t.length <= max) ? t : '${t.substring(0, max - 1)}…';
  }

  static String _signedDollar(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign\$${v.toStringAsFixed(0)}';
  }

  static String _longDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, '
        '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static String? _cancellationUrl(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('spotify')) return 'https://www.spotify.com/account/subscription/';
    if (lower.contains('netflix')) return 'https://www.netflix.com/cancelplan';
    if (lower.contains('disney')) return 'https://www.disneyplus.com/account/subscription';
    if (lower.contains('apple music') || lower.contains('apple tv') || lower.contains('icloud')) {
      return 'https://support.apple.com/en-nz/HT202039';
    }
    if (lower.contains('youtube') || lower.contains('google')) return 'https://myaccount.google.com/subscriptions';
    if (lower.contains('amazon') || lower.contains('prime')) return 'https://www.amazon.com/gp/primecentral';
    if (lower.contains('neon')) return 'https://www.neontv.co.nz/account';
    if (lower.contains('cityfitness') || lower.contains('city fitness')) return 'Contact gym directly or visit cityfitness.co.nz';
    if (lower.contains('les mills')) return 'https://www.lesmills.co.nz/';
    if (lower.contains('anytime fitness')) return 'Contact your local club';
    if (lower.contains('openai') || lower.contains('chatgpt')) return 'https://platform.openai.com/account/billing';
    if (lower.contains('microsoft') || lower.contains('xbox')) return 'https://account.microsoft.com/services';
    if (lower.contains('adobe')) return 'https://account.adobe.com/plans';
    if (lower.contains('canva')) return 'https://www.canva.com/settings/billing-and-plans';
    if (lower.contains('spark')) return 'https://www.spark.co.nz/myaccount';
    if (lower.contains('vodafone')) return 'https://www.vodafone.co.nz/my-vodafone';
    if (lower.contains('2degrees')) return 'https://www.2degrees.nz/my2degrees';
    return null;
  }
}
