import 'dart:convert';

import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/chat_storage.dart';
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
You are an assistant that extracts structured action data from a chat between a financial coach and a student.

Valid action types:
- goal: a savings goal with a target amount and weekly contribution.
- budget: a weekly spending cap for a category.
- alert: a one-off reminder for an upcoming bill or payment.

CRITICAL RULES FOR EXTRACTING DATA:
1. ALWAYS prioritize values from the ASSISTANT's latest reply over the user's raw text.
   - If the assistant said "Name: Bike, Target: \$2,000, Weekly: \$50", use THOSE exact values.
   - Do NOT use the user's wording (e.g., "a 2k bike") if the assistant provided cleaner values.

2. For titles/names:
   - Use the name the ASSISTANT specified (e.g., "Bike" not "a 2k bike").
   - If no name was specified by either, use "goal", "alert", or "budget".

3. For amounts:
   - Use the EXACT numbers from the assistant's response when available.
   - The "amount" field is the TARGET amount (total to save).
   - The "weekly_amount" field is the WEEKLY CONTRIBUTION (how much per week).
   - These are DIFFERENT numbers - do not confuse them!

4. For timelines:
   - If a goal has a timeline, compute weekly_amount = amount / max(weeks, 1).
   - Weeks = days / 7. Use 30 days per month, 365 days per year.

5. When user mentions a bill/payment:
   - Emit BOTH a goal (for saving) and an alert (for reminder).

Return ONLY valid JSON:
[
  {
    "type": "goal" | "budget" | "alert",
    "title": "short clean name",
    "description": "original user request",
    "amount": 2000.00,
    "weekly_amount": 50.00,
    "category": "name if relevant",
    "due_date": "YYYY-MM-DD",
    "due_in_days": 14,
    "note": "extra info"
  }
]

- Use null when information is missing.
- Keep amounts positive.
- If no actions needed, return [].
''';

  Future<List<ChatSuggestedAction>> identifyActions(
    List<Map<String, String>> recentTurns, {
    String? assistantReply,
  }) async {
    final apiKey = await ApiKeyStore.get();
    if (apiKey == null || apiKey.isEmpty) {
      return const [];
    }

    final todayLabel = _todayLabel();
    final memory = await _buildConversationMemory();
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'Today is $todayLabel. Use today\'s date when reasoning about due dates or pay cycles.',
      },
      if (memory.isNotEmpty)
        {
          'role': 'system',
          'content': 'Conversation memory (older context):\n$memory',
        },
      if (assistantReply != null && assistantReply.trim().isNotEmpty)
        {
          'role': 'system',
          'content':
              'IMPORTANT - Latest assistant reply (EXTRACT VALUES FROM THIS when available):\n${assistantReply.trim()}',
        },
      {'role': 'system', 'content': _systemPrompt},
      ...recentTurns,
      {
        'role': 'system',
        'content': 'Respond with JSON only. No commentary. Remember to use values from the assistant reply above.',
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

  Future<String> _buildConversationMemory({int maxBullets = 8}) async {
    final all = await ChatStorage().loadAllMessages();
    if (all.isEmpty) return '';
    const keepTail = 6;
    final head = (all.length > keepTail)
        ? all.sublist(0, all.length - keepTail)
        : const <ChatMessage>[];
    final tail = all.takeLast(keepTail).toList();
    final bullets = <String>[];
    if (head.isNotEmpty) {
      for (final m in head) {
        if (m.role != ChatRole.user) continue;
        final clipped = _clip(m.content, 140);
        if (clipped.isNotEmpty) bullets.add('- $clipped');
        if (bullets.length >= maxBullets - 2) break;
      }
    }
    for (final m in tail) {
      if (m.role == ChatRole.user) {
        bullets.add('- recent_user: ${_clip(m.content, 140)}');
      }
      if (bullets.length >= maxBullets) break;
    }
    return bullets.join('\n');
  }

  String _clip(String s, int max) {
    final t = s.trim().replaceAll('\n', ' ');
    return (t.length <= max) ? t : '${t.substring(0, max - 1)}...';
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

extension _TakeLast<E> on List<E> {
  Iterable<E> takeLast(int n) {
    if (n <= 0) return const Iterable.empty();
    if (length <= n) return this;
    return sublist(length - n);
  }
}
