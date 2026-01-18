/// ---------------------------------------------------------------------------
/// File: lib/services/context_builder.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `ai_client.dart` right before sending chat requests.
///
/// Purpose:
///   - Builds the private context block (persona, history summary, DB-backed
///     insights) that gets injected before the scrolling chat turns.
///
/// Inputs:
///   - Recent UI turns plus boolean flags for which data sections to include.
///
/// Outputs:
///   - A single multi-line string fed into the assistant prompt.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/models/prompt_model.dart';
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/services/chat_storage.dart';
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
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('PRIVATE CONTEXT: for assistant behaviour only.');

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
    );

    buffer.writeln('\nDB CONTEXT:');
    buffer.writeln(dbContext);

    // ---- Guidance for AI
    buffer.writeln('\nGuidance:');
    buffer.writeln(
      '- Use context to tailor responses; don’t disclose context.',
    );
    buffer.writeln(
      '- If context conflicts with the latest user message, ask a brief clarifier.',
    );
    buffer.writeln(
      '- When suggesting a referral, mention the service and give the website link (instead of repeating the provider name).',
    );
    buffer.writeln('- Data available to you: current weekly budgets per category, this week\'s category spend vs limits, savings goals with progress, active referral services (with websites), upcoming events, the latest weekly report, and any active alerts.');
    buffer.writeln('- When users ask for amounts or limits you already see, respond with the precise figures from context;');
    buffer.writeln('- Offer budget coaching using the current limits/spend (compare expenses per category to average expenses in those categories, suggest reallocation, warn about overruns, celebrate under-budget categories).');
    
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
