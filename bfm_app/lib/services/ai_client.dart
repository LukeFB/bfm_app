/// ---------------------------------------------------------------------------
/// File: lib/services/ai_client.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `chat_screen.dart` when the user sends a message.
///
/// Purpose:
///   - Chat completion client (no backend):
///       • Injects the Moni system prompt (policy/tone/safety).
///       • Injects PRIVATE CONTEXT built by `ContextBuilder`.
///       • Sends recent user/assistant turns after the context.
///
/// Inputs:
///   - Recent chat turns (`role`, `content`) and the stored API key.
///
/// Outputs:
///   - Assistant reply text powered by OpenAI.
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/context_builder.dart';

/// Lightweight OpenAI chat client that injects the Moni system prompt and
/// private context before sending the latest chat history.
class AiClient {
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';

  // TODO: gpt-5-mini
  static const String _model = 'gpt-4o-mini';
  static const double _temperature = 0.7;
  static const int _maxTokens = 800; // Cost control

  // TODO: refine with stakeholders as needed (BFM policy)
  static const String _systemPrompt = '''
  You are Moni AI — Bay Financial Mentors’ (BFM) supportive financial wellbeing mate for university students in Aotearoa New Zealand.

Do: provide support, education, options, and referrals. Ask clarifying questions, explain simply, and help the user choose what fits them.
Don’t: give personalised financial, legal, tax, investment, or medical advice; shame; prescribe (“you must/should”). Prefer: “You could…”, “Have you considered…”, “Some students find…”.

Tone: warm, inclusive, down-to-earth NZ English (Kia ora / light te reo where natural). Use “we” language. Respect Māori whānau and Pacific/family obligations (incl. remittances) as valid.

Style: brief empathy → 1–3 clarifying questions → 1–3 practical next steps → ask permission to go deeper. Short paragraphs, avoid overwhelming lists, minimal emojis.

Safety/escalation: If essentials are unaffordable, urgent enforcement, scam/identity risk, violence/financial control, severe distress, self-harm:
- prioritise safety, validate feelings, encourage immediate human help.
- refer to BFM ({{BFM_PHONE}}/{{BFM_EMAIL}}) and appropriate NZ services (e.g., 111, 1737, Women’s Refuge, Netsafe, Tenancy Services, MoneyTalks) using the app’s up-to-date directory.
- pause non-urgent coaching until safety/essentials are addressed.

Privacy: never ask for PINs/passwords; only use app-provided data. Ask before remembering personal details; respect “don’t remember”.

First chat defaults: ask preferred name, student status, what they want help with today, and memory preference.

''';

  /// Completes a turn in the chat flow by combining the system prompt, freshly
  /// built private context, and the latest user/assistant turns before calling
  /// OpenAI. Throws when no API key is stored or the API returns an error.
  Future<String> complete(List<Map<String, String>> recentTurns) async {
    final apiKey = await ApiKeyStore.get();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No API key set. Add one in Settings.');
    }

    // Build PRIVATE CONTEXT fresh each turn
    final contextStr = await ContextBuilder.build(
      recentTurns: recentTurns,
      includeBudgets: true, // TODO: expose as a Settings toggle
      includeCategories: true,
      includeReferrals: true, // TODO: expose as a Settings toggle
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'system', 'content': contextStr}, // PRIVATE CONTEXT
      ...recentTurns,
    ];

    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'temperature': _temperature,
    };
    body['max_tokens'] = _maxTokens;

    // retry
    http.Response res;
    int attempt = 0;
    while (true) {
      attempt++;
      res = await http
          .post(
            Uri.parse(_openAiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 429 || res.statusCode >= 500) {
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 300 * attempt * attempt));
          continue;
        }
      }
      break;
    }

    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body);
        final msg = (err is Map && err['error'] is Map)
            ? (err['error']['message']?.toString() ?? res.body)
            : res.body;
        throw Exception('OpenAI error ${res.statusCode}: $msg');
      } catch (_) {
        throw Exception('OpenAI error ${res.statusCode}: ${res.body}');
      }
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?) ?? const [];
    final content = choices.isNotEmpty
        ? (choices.first as Map)['message']['content'] as String?
        : null;

    return (content != null && content.trim().isNotEmpty)
        ? content.trim()
        : 'Kia ora — I’m here. How can I help today?';
  }
}
