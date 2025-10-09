/// ---------------------------------------------------------------------------
/// File: lib/services/ai_client.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   Chat completion client (no backend).
///   - Injects BFM SYSTEM PROMPT (policy/tone/safety).
///   - Injects PRIVATE CONTEXT built by ContextBuilder (summary, budgets, referrals).
///   - Sends recent user/assistant turns after the context.
///
/// TODO hooks:
///   - Adjust model/temperature/maxTokens
///   - Update SYSTEM PROMPT with BFM-approved language
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/context_builder.dart';

class AiClient {
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';

  // TODO: pick your preferred model & tuning
  static const String _model = 'gpt-4o-mini';
  static const double _temperature = 0.7;
  static const int? _maxTokens = null; // e.g., 512 if you want a cap

  // TODO: refine with stakeholders as needed (BFM policy)
  static const String _systemPrompt = '''
You are “Moni AI”, a supportive financial wellbeing assistant created by Bay Financial Mentors (BFM) for university students in Aotearoa New Zealand.

Core principles:
- Support, not advice. Offer education, options and referrals; avoid prescriptive financial advice.
- Warm, inclusive, non-judgmental tone. Use plain NZ English. "Kia ora" is welcome.
- Cultural sensitivity: respect Māori whānau perspectives and Pacific obligations (e.g., remittances).
- Safety: if user mentions inability to afford essentials, crisis, or harm, gently encourage contacting BFM or appropriate services; never dismiss feelings.
- Practicality: short, clear steps; optional links to trusted NZ resources; avoid overwhelming lists.

Style:
- Empathise briefly → clarify → offer 1–3 next steps → ask permission to go deeper.
- Keep paragraphs short. Use emojis sparingly (e.g., 💡, ✅) where helpful.

Out of scope:
- No legal, tax, investment, or medical advice.
- No judgment or shaming language.
''';

  /// Complete a turn using:
  ///   SYSTEM → PRIVATE CONTEXT → recentTurns (user/assistant)
  Future<String> complete(List<Map<String, String>> recentTurns) async {
    final apiKey = await ApiKeyStore.get();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No API key set. Add one in Settings.');
    }

    // Build PRIVATE CONTEXT fresh each turn
    final contextStr = await ContextBuilder.build(
      recentTurns: recentTurns,
      includeBudgets: true,   // TODO: expose as a Settings toggle if desired
      includeReferrals: true, // TODO: expose as a Settings toggle if desired
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'assistant', 'content': contextStr}, // PRIVATE CONTEXT
      ...recentTurns,
    ];

    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'temperature': _temperature,
    };
    if (_maxTokens != null) body['max_tokens'] = _maxTokens;

    final res = await http.post(
      Uri.parse(_openAiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('OpenAI error ${res.statusCode}: ${res.body}');
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
