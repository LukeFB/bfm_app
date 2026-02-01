// ---------------------------------------------------------------------------
// File: lib/services/context_builder.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - `ai_client.dart` right before sending chat requests.
//
// Purpose:
//   - Builds the private context block (persona, history summary, DB-backed
//     insights) that gets injected before the scrolling chat turns.
//
// Inputs:
//   - Recent UI turns plus boolean flags for which data sections to include.
//
// Outputs:
//   - A single multi-line string fed into the assistant prompt.
// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/models/prompt_model.dart';
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/chat_insights_service.dart';
import 'package:bfm_app/services/onboarding_store.dart';

/// Produces the assistant's private context using stored chat + DB data.
class ContextBuilder {
  /// Builds the PRIVATE CONTEXT block inserted before streaming the user's
  /// latest turns. `[recentTurns]` should already be trimmed/role-mapped.
  static Future<String> build({
    required List<Map<String, String>> recentTurns,
    bool includeCategories = true,
    bool includeBudgets = true,
    bool includeReferrals = true,
    bool includeGoals = true,
    bool includeReports = true,
    bool includeEvents = true,
    bool includeAlerts = true,
    bool includeRecurring = true,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('PRIVATE CONTEXT: for assistant behaviour only.');

    final now = DateTime.now();
    buffer.writeln('current_datetime_iso: ${now.toIso8601String()}');
    buffer.writeln('current_date_nz: ${_formatLongDate(now)}');

    // ---- Persona / flags
    final persona = await _getPersonaTag();
    if (persona != null) {
      buffer.writeln('persona: $persona');
    }

    final onboardingProfile = await _buildOnboardingProfileSummary();
    if (onboardingProfile.isNotEmpty) {
      buffer.writeln(
        '\nonboarding_profile (optional answers provided by user):',
      );
      buffer.writeln(onboardingProfile);
    }

    // ---- Past conversation summary
    final convoSummary = await _buildConversationSummary(maxBullets: 10);
    if (convoSummary.isNotEmpty) {
      buffer.writeln('\nconversation_summary (bullets):');
      buffer.writeln(convoSummary);
    }

    // ---- Comprehensive Financial Insights (proactive problem identification)
    buffer.writeln('\n=== FINANCIAL INSIGHTS ===');
    try {
      final insights = await ChatInsightsService.buildComprehensiveContext();
      buffer.writeln(insights);
    } catch (_) {
      buffer.writeln('Unable to load comprehensive insights.');
    }

    // ---- Budgets + referrals (DB-backed via PromptModel)
    final db = await AppDatabase.instance.database;
    final promptModel = PromptModel(db);
    final dbContext = await promptModel.buildPrompt(
      includeBudgets: includeBudgets,
      includeCategories: includeCategories,
      includeReferrals: includeReferrals,
      includeGoals: includeGoals,
      includeReports: includeReports,
      includeEvents: includeEvents,
      includeAlerts: includeAlerts,
      includeRecurring: includeRecurring,
    );

    buffer.writeln('\n=== DETAILED DATA ===');
    buffer.writeln(dbContext);

    // ---- Capabilities and Limitations
    buffer.writeln('\n=== YOUR CAPABILITIES ===');
    buffer.writeln('');
    buffer.writeln('ACTIONS (via action buttons after your response):');
    buffer.writeln('1. CREATE SAVINGS GOAL: Help save for something specific');
    buffer.writeln('   - Needs: name, target amount, weekly contribution');
    buffer.writeln('   - Optionally create linked alert for due date');
    buffer.writeln('   - Auto-creates a budget entry for the goal');
    buffer.writeln('');
    buffer.writeln('2. CREATE ALERT: Remind about upcoming bills/payments');
    buffer.writeln('   - Needs: title, optional amount, optional due date');
    buffer.writeln('   - Schedules notification reminder');
    buffer.writeln('');
    buffer.writeln('3. CREATE BUDGET: Set weekly spending limit for category');
    buffer.writeln('   - Needs: category name, weekly limit');
    buffer.writeln('');
    buffer.writeln('DATA ACCESS:');
    buffer.writeln('- Weekly income (from recurring or last week)');
    buffer.writeln('- All budgets with limits and spend');
    buffer.writeln('- Category spending averages (identifies overspending)');
    buffer.writeln('- Savings goals with progress');
    buffer.writeln('- Recurring subscriptions with due dates');
    buffer.writeln('- Active alerts');
    buffer.writeln('- Referral services');
    buffer.writeln('');
    buffer.writeln('HOW TO HELP:');
    buffer.writeln('- Answer what the user asks - don\'t proactively suggest creating budgets/goals/alerts');
    buffer.writeln('- Only offer to create budgets, goals, or alerts if the user explicitly asks');
    buffer.writeln('- Quote specific numbers from data (do not guess)');
    buffer.writeln('- Suggest relevant referral services when appropriate');
    buffer.writeln('- If user asks about their spending, just answer the question - don\'t suggest fixes');
    buffer.writeln('');
    buffer.writeln('LIMITATIONS:');
    buffer.writeln('- Cannot directly modify budgets/goals/alerts');
    buffer.writeln('- Can only suggest actions (user confirms via button)');
    buffer.writeln('- Cannot access individual transactions');
    buffer.writeln('- Cannot make payments or transfers');
    buffer.writeln('');
    buffer.writeln('APP SCREENS TO DIRECT USERS TO:');
    buffer.writeln('- Insights: For spending analysis, category breakdowns, weekly reports');
    buffer.writeln('- Dashboard: For quick overview of budget and left to spend');
    buffer.writeln('- Budgets: For setting/editing weekly spending limits');
    buffer.writeln('- Savings: For tracking savings goals');
    buffer.writeln('- Subscriptions: For viewing recurring bills');
    buffer.writeln('- Transactions: For viewing/searching/categorizing transactions');
    buffer.writeln('');
    buffer.writeln('IMPORTANT: Uncategorized budgets track SPECIFIC recurring transactions by name,');
    buffer.writeln('NOT total uncategorized spend. Never compare them - they are unrelated.');
    buffer.writeln('');
    buffer.writeln('END CONTEXT.');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Past conversation summary
  // ---------------------------------------------------------------------------
  /// Summarises older chat history into bullet points plus a few recent user
  /// lines so the assistant remembers long-running threads.
  static Future<String> _buildConversationSummary({int maxBullets = 10}) async {
    final all = await ChatStorage().loadAllMessages();
    if (all.isEmpty) return '';

    const kKeepTail = 8;
    final head = (all.length > kKeepTail)
        ? all.sublist(0, all.length - kKeepTail)
        : const <ChatMessage>[];
    final tail = all.takeLast(kKeepTail).toList();

    final bullets = <String>[];

    if (head.isNotEmpty) {
      final grouped = _compressByTopic(head, limit: 5);
      for (final g in grouped) {
        bullets.add('• ${g.trim()}');
      }
    }

    for (final m in tail) {
      if (m.role == ChatRole.user) {
        bullets.add('• recent_user: ${_clip(m.content, 140)}');
      }
      if (bullets.length >= maxBullets) break;
    }

    return bullets.join('\n');
  }

  /// Picks the first few user messages and clips them for summary bullets.
  static List<String> _compressByTopic(
    List<ChatMessage> msgs, {
    int limit = 5,
  }) {
    final out = <String>[];
    for (final m in msgs) {
      if (m.role == ChatRole.user) {
        final s = _clip(m.content, 140);
        if (s.isNotEmpty) out.add(s);
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Persona
  // ---------------------------------------------------------------------------
  /// Placeholder for future persona tagging (e.g., family vs business budget).
  static Future<String?> _getPersonaTag() async {
    // TODO: wire to user profile store
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  /// Trims whitespace and caps a string at `max` characters with an ellipsis.
  static String _clip(String s, int max) {
    final t = s.trim().replaceAll('\n', ' ');
    return (t.length <= max) ? t : '${t.substring(0, max - 1)}…';
  }

  static String _formatLongDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[d.weekday - 1];
    final month = months[d.month - 1];
    final day = d.day.toString().padLeft(2, '0');
    return '$weekday, $day $month ${d.year} (local NZ time)';
  }

  /// Loads the onboarding answers and formats them for the private context.
  static Future<String> _buildOnboardingProfileSummary() async {
    final OnboardingResponse? response = await OnboardingStore().getResponse();
    if (response == null || !response.hasAnswers) return '';
    final map = response.toDisplayMap();
    if (map.isEmpty) return '';
    final lines = map.entries
        .map((entry) => '- ${entry.key}: ${entry.value}')
        .join('\n');
    return lines;
  }
}

extension _TakeLast<E> on List<E> {
  /// Pulls the last `n` items without copying when the list is already short.
  Iterable<E> takeLast(int n) {
    if (n <= 0) return const Iterable.empty();
    if (length <= n) return this;
    return sublist(length - n);
  }
}
