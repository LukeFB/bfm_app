import 'dart:convert';

import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:http/http.dart' as http;

/// Calls OpenAI with a lightweight instruction to detect structured follow-up
/// actions (goals, budgets, alerts) from recent chat turns.
class ChatActionExtractor {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';
  static const _maxTokens = 400;
  static const _systemPrompt = '''
You are an assistant that inspects the most recent chat between a financial coach and a student. Identify any concrete follow-up actions that can be saved inside the app.

Valid action types:
- goal: a savings goal with a target amount or contribution.
- budget: a weekly spending cap for a category.
- alert: a one-off reminder for an upcoming bill or payment.

Rules:
- When the user mentions an upcoming bill, payment, invoice, or repair they need to cover, emit BOTH a `goal` action (for saving the amount) and an `alert` action (to remind them before it is due). Infer due dates or use due_in_days when only a timeframe is provided.
- Never invent amounts; reuse the user’s numbers. Keep amounts positive.

Return ONLY valid JSON using this shape:
[
  {
    "type": "goal" | "budget" | "alert",
    "title": "short label (optional)",
    "description": "how the user described it",
    "amount": 123.45,
    "weekly_amount": 25.0,
    "category": "name of category if relevant",
    "due_date": "YYYY-MM-DD",
    "due_in_days": 14,
    "note": "extra instructions"
  }
]

- Use null when information is missing.
- Keep numbers positive.
- If no actions are needed return [].
''';

  Future<List<ChatSuggestedAction>> identifyActions(
      List<Map<String, String>> recentTurns) async {
    final apiKey = await ApiKeyStore.get();
    if (apiKey == null || apiKey.isEmpty) {
      return const [];
    }

    final todayLabel = _todayLabel();
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'Today is $todayLabel. Use today’s date when reasoning about due dates or pay cycles.',
      },
      {'role': 'system', 'content': _systemPrompt},
      ...recentTurns,
      {
        'role': 'system',
        'content': 'Respond with JSON only. No commentary.',
      },
    ];

    final body = <String, dynamic>{
      'model': _model,
      'temperature': 0,
      'max_tokens': _maxTokens,
      'messages': messages,
    };

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = (data['choices'] as List?) ?? const [];
      if (choices.isEmpty) return const [];
      final content = (choices.first as Map)['message']['content'];
      if (content is! String || content.trim().isEmpty) {
        return const [];
      }
      final actions = ChatSuggestedAction.listFromDynamic(content);
      if (actions.isEmpty) return const [];
      return actions.take(3).toList();
    } catch (_) {
      return const [];
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
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
    final month = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    return '$day $month ${now.year} (local NZ time)';
  }
}
