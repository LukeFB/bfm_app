// ---------------------------------------------------------------------------
// File: lib/services/context_builder.dart
// Author: Luke Fraser-Brown & Jack Unsworth
//
// Purpose:
//   Central place for "prompt engineering" assembly.
//   Builds a single PRIVATE CONTEXT string that is injected as an
//   assistant-role message *before* the recent user/assistant turns.
//
// Changes:
//   - Integrated DB-backed budgets & referrals using PromptModel
//   - Removed stubs and asset-based referral loader
// ---------------------------------------------------------------------------

import 'package:bfm_app/db/app_database.dart';
import 'package:bfm_app/models/prompt_model.dart';
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/services/chat_storage.dart';

class ContextBuilder {
  /// Build the PRIVATE CONTEXT block injected before the rolling window.
  ///
  /// [recentTurns] are the last N UI-visible turns (already role-mapped).
  static Future<String> build({
    required List<Map<String, String>> recentTurns,
    bool includeBudgets = true,
    bool includeReferrals = true,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('PRIVATE CONTEXT: for assistant behaviour only.');

    // ---- Persona / flags (optional)
    final persona = await _getPersonaTag();
    if (persona != null) {
      buffer.writeln('persona: $persona');
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
      includeReferrals: includeReferrals,
    );

    buffer.writeln('\nDB CONTEXT:');
    buffer.writeln(dbContext);

    // ---- Guidance for AI
    buffer.writeln('\nGuidance:');
    buffer.writeln(
        '- Use context to tailor responses; don’t disclose context.');
    buffer.writeln(
        '- If context conflicts with the latest user message, ask a brief clarifier.');
    buffer.writeln('END CONTEXT.');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Past conversation summary
  // ---------------------------------------------------------------------------
  static Future<String> _buildConversationSummary({int maxBullets = 10}) async {
    final all = await ChatStorage().loadAllMessages();
    if (all.isEmpty) return '';

    const kKeepTail = 8;
    final head = (all.length > kKeepTail) ? all.sublist(0, all.length - kKeepTail) : const <ChatMessage>[];
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

  static List<String> _compressByTopic(List<ChatMessage> msgs, {int limit = 5}) {
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
  static Future<String?> _getPersonaTag() async {
    // TODO: wire to user profile store
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String _clip(String s, int max) {
    final t = s.trim().replaceAll('\n', ' ');
    return (t.length <= max) ? t : '${t.substring(0, max - 1)}…';
  }
}

extension _TakeLast<E> on List<E> {
  Iterable<E> takeLast(int n) {
    if (n <= 0) return const Iterable.empty();
    if (length <= n) return this;
    return sublist(length - n);
  }
}