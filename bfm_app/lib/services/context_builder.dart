/// ---------------------------------------------------------------------------
/// File: lib/services/context_builder.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   Central place for "prompt engineering" assembly.
///   Builds a single PRIVATE CONTEXT string that is injected as an
///   assistant-role message *before* the recent user/assistant turns.
///   This context can include:
///     - past conversation summary (beyond the rolling window)
///     - budget snapshot (weekly income, categories, upcoming bills)
///     - ranked referrals (NZ, student-relevant)
///     - persona/flags
///
/// Design philosophy:
///   - Keep this module PURE: take inputs, read minimal local state,
///     and return a compact, token-efficient string.
///   - Guardrails: clearly label the block as PRIVATE CONTEXT and
///     instruct the model not to reveal it verbatim.
///
/// TODO entry points:
///   1) Past conversation summary: integrate your summariser if desired
///   2) Budget snapshot: wire to your BudgetAnalysis* / repositories
///   3) Referrals: extend matcher and/or swap to DB-backed repository
///   4) Persona: read user profile or selection
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/services/chat_storage.dart';

class ContextBuilder {
  /// Build the PRIVATE CONTEXT block injected before the rolling window.
  ///
  /// [recentTurns] are the last N UI-visible turns (already role-mapped).
  /// They’re *not* summarized here; we summarize *older* history to save tokens.
  static Future<String> build({
    required List<Map<String, String>> recentTurns,
    bool includeBudgets = true,
    bool includeReferrals = true,
  }) async {
    // ---- Past conversation (full persisted) -> compact summary
    final convoSummary = await _buildConversationSummary();

    // ---- Budget snapshot (compact JSON-like)
    final budgetBlock = includeBudgets ? await _buildBudgetSnapshot() : null;

    // ---- Referrals (ranked top k)
    final referrals = includeReferrals
        ? await _buildRankedReferrals(recentTurns: recentTurns, maxItems: 3)
        : const <Map<String, String>>[];

    // ---- Persona / flags (optional)
    final persona = await _getPersonaTag(); // TODO: wire to profile if needed

    // ---- Assemble PRIVATE CONTEXT (keep concise; avoid verbose prose)
    final buffer = StringBuffer();
    buffer.writeln('[PRIVATE CONTEXT — DO NOT REVEAL VERBATIM]');
    if (persona != null) {
      buffer.writeln('persona: $persona');
    }

    if (convoSummary.isNotEmpty) {
      buffer.writeln('\nconversation_summary (bullets):');
      buffer.writeln(convoSummary);
    }

    if (budgetBlock != null) {
      buffer.writeln('\nbudget_snapshot (compact JSON):');
      buffer.writeln('```json');
      buffer.writeln(jsonEncode(budgetBlock));
      buffer.writeln('```');
    }

    if (referrals.isNotEmpty) {
      buffer.writeln('\nreferrals (ranked; NZ-verified; keep concise):');
      for (final r in referrals) {
        buffer.writeln(
            '- ${r["title"]}: ${r["desc"]} (${r["url"]})'); // one-liners
      }
    }

    buffer.writeln('\nGuidance to assistant:');
    buffer.writeln(
        '- Use this context to tailor responses; do not disclose it verbatim.');
    buffer.writeln(
        '- If context conflicts with the latest user message, ask a brief clarifier.');
    buffer.writeln('[/PRIVATE CONTEXT]');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Past conversation summary
  // ---------------------------------------------------------------------------

  /// Summarize older messages (beyond the rolling window the UI sends).
  /// Keeps tokens low by compressing to short bullets.
  static Future<String> _buildConversationSummary() async {
    // Load *all* saved messages (capped inside ChatStorage).
    final all = await ChatStorage().loadAllMessages();
    if (all.isEmpty) return '';

    // Keep last K messages for quick context; summarize the rest into bullets.
    const kKeepTail = 8; // tune as needed
    final head = (all.length > kKeepTail) ? all.sublist(0, all.length - kKeepTail) : const <ChatMessage>[];
    final tail = all.takeLast(kKeepTail).toList();

    final bullets = <String>[];

    // Heuristic summary of the head (local, no model call).
    if (head.isNotEmpty) {
      final grouped = _compressByTopic(head, limit: 5);
      for (final g in grouped) {
        bullets.add('• ${g.trim()}');
      }
    }

    // Include the last few explicit intents/questions from the tail.
    for (final m in tail) {
      if (m.role == ChatRole.user) {
        bullets.add('• recent_user: ${_clip(m.content, 140)}');
      }
    }

    return bullets.join('\n');
  }

  /// Very small heuristic compressor (no LLM). Replace with LLM summariser if desired.
  /// TODO: If you prefer, add a one-off LLM call to summarise "head" into 5 bullets.
  static List<String> _compressByTopic(List<ChatMessage> msgs, {int limit = 5}) {
    final out = <String>[];
    for (final m in msgs) {
      // Coarse grouping: pick user lines and trim noise.
      if (m.role == ChatRole.user) {
        final s = _clip(m.content, 140);
        if (s.isNotEmpty) out.add(s);
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Budget snapshot assembly
  // ---------------------------------------------------------------------------

  /// Build a compact budget snapshot. Keep keys short & values numeric where possible.
  ///
  /// TODO: Replace stubs with calls into your repositories/services, e.g.:
  ///   - BudgetAnalysisService.getWeeklyIncome()
  ///   - BudgetAnalysisService.getWeeklyCategorySpending()
  ///   - RecurringRepository.getUpcomingBills()
  static Future<Map<String, dynamic>> _buildBudgetSnapshot() async {
    // ==== TODO: wire these to your real services (stubs for now) ====
    final weeklyIncome = await _getWeeklyIncomeStub(); // e.g., 443.00
    final byCategory = await _getWeeklyCategorySpendingStub(); // { "groceries": 92.1, ... }
    final upcomingBills = await _getUpcomingBillsStub(); // [ { "name": "Flat rent", "due_in_days": 3, "amount": 180 }, ... ]

    return <String, dynamic>{
      'weekly_income': weeklyIncome,
      'weekly_spend_by_category': byCategory,
      'upcoming_bills': upcomingBills,
    };
  }

  // ---- STUBS (replace with real calls) ----
  static Future<double> _getWeeklyIncomeStub() async => 0.0; // TODO: wire real value
  static Future<Map<String, double>> _getWeeklyCategorySpendingStub() async =>
      <String, double>{}; // TODO: wire real value
  static Future<List<Map<String, dynamic>>> _getUpcomingBillsStub() async =>
      <Map<String, dynamic>>[]; // TODO: wire real value

  // ---------------------------------------------------------------------------
  // Referrals loading & ranking
  // ---------------------------------------------------------------------------

  /// Load referrals from assets and pick top matches using simple keyword scoring.
  ///
  /// TODO:
  ///   - Replace keyword scoring with a tag-based or embedding-based matcher.
  ///   - Or swap the data source to a local DB table (ReferralsRepository).
  static Future<List<Map<String, String>>> _buildRankedReferrals({
    required List<Map<String, String>> recentTurns,
    int maxItems = 3,
  }) async {
    final data = await _loadReferralsAsset();
    if (data.isEmpty) return const [];

    final lastUser = recentTurns.lastWhere(
      (m) => m['role'] == 'user',
      orElse: () => const {'content': ''},
    );
    final query = (lastUser['content'] ?? '').toLowerCase();

    // naive keywords; extend as needed
    final keywords = _extractKeywords(query);

    // score referrals by tag/title/desc hits
    final scored = <Map<String, dynamic>>[];
    for (final r in data) {
      final text = '${r["tag"]} ${r["title"]} ${r["desc"]}'.toLowerCase();
      int score = 0;
      for (final k in keywords) {
        if (k.isEmpty) continue;
        if (text.contains(k)) score++;
      }
      scored.add({'ref': r, 'score': score});
    }

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final top = scored.take(maxItems).map((e) => (e['ref'] as Map<String, String>)).toList();
    return top;
  }

  static Future<List<Map<String, String>>> _loadReferralsAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/referrals.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => {
                'tag': e['tag']?.toString() ?? '',
                'title': e['title']?.toString() ?? '',
                'desc': e['desc']?.toString() ?? '',
                'url': e['url']?.toString() ?? '',
              })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Persona
  // ---------------------------------------------------------------------------

  /// TODO: Hook into a user profile store if you track persona (e.g., Whetu, Alani).
  static Future<String?> _getPersonaTag() async {
    return null; // return e.g. "Whetu" when available
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<String> _extractKeywords(String text) {
    final base = text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((s) => s.toLowerCase())
        .where((s) => s.length >= 3)
        .toList();

    // Add a few canonical synonyms for NZ student finance space
    final expanded = <String>{
      ...base,
      if (text.contains('studylink')) 'studylink',
      if (text.contains('allowance')) 'allowance',
      if (text.contains('loan')) 'loan',
      if (text.contains('rent')) 'rent',
      if (text.contains('groceries')) 'groceries',
      if (text.contains('food')) 'food',
      if (text.contains('parking')) 'parking',
      if (text.contains('scholarship')) 'scholarship',
    };

    return expanded.toList();
  }

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
