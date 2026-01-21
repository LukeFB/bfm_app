import 'dart:convert';

import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:http/http.dart' as http;

/// Calls OpenAI with a lightweight instruction to detect structured follow-up
/// actions (goals, budgets, alerts) from recent chat turns.
class ChatActionExtractor {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-5-mini';
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const _maxTokens = 400;
  static const _reasoningEffort = 'low';
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
      // GPT-5 mini only allows the default temperature value (1.0).
      'temperature': 1,
      'max_completion_tokens': _maxTokens,
      'messages': messages,
      'reasoning_effort': _reasoningEffort,
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
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractAssistantText(data);
      if (content == null || content.trim().isEmpty) {
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
  String? _extractAssistantText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List) {
      for (final choice in choices) {
        final text = _extractChoiceText(choice);
        if (_hasContent(text)) return text;
      }
    }

    final altKeys = [
      'output',
      'content',
      'response',
      'result',
      'message',
      'messages',
      'text',
    ];
    for (final key in altKeys) {
      if (data.containsKey(key)) {
        final altText = _stringifyContent(data[key]).trim();
        if (altText.isNotEmpty) return altText;
      }
    }
    return null;
  }

  bool _hasContent(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String? _extractChoiceText(dynamic choice) {
    if (choice is! Map) return null;
    final messageText = _extractMessageText(choice['message']);
    if (_hasContent(messageText)) {
      return messageText;
    }
    final choiceText = _stringifyContent(choice['text']).trim();
    if (choiceText.isNotEmpty) return choiceText;
    final outputText = _stringifyContent(choice['output']).trim();
    if (outputText.isNotEmpty) return outputText;
    final contentText = _stringifyContent(choice['content']).trim();
    if (contentText.isNotEmpty) return contentText;
    final deltaText = _stringifyContent(choice['delta']).trim();
    if (deltaText.isNotEmpty) return deltaText;
    return null;
  }

  String? _extractMessageText(dynamic message) {
    if (message is! Map) return null;
    final text = _stringifyContent(message['content']).trim();
    if (text.isNotEmpty) return text;
    final outputText = _stringifyContent(message['output_text']).trim();
    if (outputText.isNotEmpty) return outputText;
    final altText = _stringifyContent(message['text']).trim();
    if (altText.isNotEmpty) return altText;
    final refusal = _stringifyContent(message['refusal']).trim();
    return refusal.isNotEmpty ? refusal : null;
  }

  String _stringifyContent(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        buffer.write(_stringifyContent(item));
      }
      return buffer.toString();
    }
    if (value is Map) {
      final keysToCheck = [
        'value',
        'text',
        'content',
        'parts',
        'output_text',
        'refusal'
      ];
      for (final key in keysToCheck) {
        if (value.containsKey(key)) {
          final text = _stringifyContent(value[key]);
          if (text.isNotEmpty) return text;
        }
      }
      if (value.containsKey('type')) {
        final type = value['type'];
        if (type == 'output_text' || type == 'input_text' || type == 'text') {
          final text = _stringifyContent(value['text']);
          if (text.isNotEmpty) return text;
        }
      }
      final buffer = StringBuffer();
      value.forEach((_, dynamic v) {
        buffer.write(_stringifyContent(v));
      });
      return buffer.toString();
    }
    return '';
  }
}
