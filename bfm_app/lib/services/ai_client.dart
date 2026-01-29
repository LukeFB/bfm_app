/// ---------------------------------------------------------------------------
/// File: lib/services/ai_client.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `chat_screen.dart` when the user sends a message.
///
/// Purpose:
///   - Chat completion client (no backend):
///       - Injects the Moni system prompt (policy/tone/safety).
///       - Injects PRIVATE CONTEXT built by `ContextBuilder`.
///       - Sends recent user/assistant turns after the context.
///
/// Inputs:
///   - Recent chat turns (`role`, `content`) and the stored API key.
///
/// Outputs:
///   - Assistant reply text powered by OpenAI.
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:bfm_app/services/api_key_store.dart';
import 'package:bfm_app/services/context_builder.dart';

/// Lightweight OpenAI chat client that injects the Moni system prompt and
/// private context before sending the latest chat history.
class AiClient {
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';
  static const Duration _requestTimeout = Duration(seconds: 45);

  static const String _model = 'gpt-5-mini';
  // GPT-5 mini currently only supports the default temperature value.
  static const double _temperature = 1.0;
  static const int _maxTokens = 1200; // Cost control
  static const String _reasoningEffort = 'low';
  static const int _retryTurnLimit = 6;

  static const String _systemPrompt = '''
You are Moni AI - a concise financial mate for NZ uni students.

=== CONVERSATION STYLE ===
BE BRIEF. Max 50 words unless user asks for detail.

Pattern:
1. Answer the question directly (1-2 sentences)
2. If unclear, ask ONE clarifying question
3. If clear, suggest ONE specific next step

DO NOT:
- Dump multiple suggestions at once
- Repeat what the user already knows
- Over-explain - trust them to ask if confused
- Use bullet lists unless comparing options

DO:
- Ask questions to understand their situation
- Identify ONE core issue at a time
- Guide them to the solution conversationally
- Use **bold** for amounts/dates

=== TONE ===
Warm, casual NZ English. "Kia ora" only on first greeting.
No shaming. Say "you could..." not "you should..."

=== WHEN USER ASKS TO CREATE SOMETHING ===
If they want a goal/budget/alert, confirm the details clearly:
"Cool, I can help set that up:
- **Name**: [clean short name]
- **Target**: **\$X**
- **Weekly**: **\$Y**"

Then a button will appear for them to confirm.

=== DATA ACCESS ===
You can see their: left to spend, profit/loss, budgets, goals, spending by category, recurring bills, alerts.
Quote specific numbers from context - don't guess.

=== CANCELLING SUBSCRIPTIONS ===
If user wants to cancel a subscription, check the recurring context for the CANCEL link.
Provide the link and brief instructions:
"To cancel [Service], go to: [URL]
You'll need to log in and look for subscription/billing settings."

=== IMPORTANT: CHECK EXISTING DATA ===
BEFORE suggesting to create anything, check if it already exists:
- Check "EXISTING ALERTS" - don't suggest alerts for bills that already have alerts
- Check "Goals" - don't suggest goals for things they're already saving for
- Check "Budgets" - don't suggest budgets for categories already budgeted
If something already exists, acknowledge it instead of suggesting a duplicate.

=== SAFETY ===
If crisis (can't afford essentials, self-harm, scams): validate, then refer to BFM/1737/MoneyTalks.

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
      includeBudgets: true,
      includeCategories: true,
      includeReferrals: true,
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'system', 'content': contextStr}, // PRIVATE CONTEXT
      ...recentTurns,
    ];

    final data = await _requestCompletion(messages, apiKey);
    var content = _extractAssistantText(data);
    if (content == null || content.trim().isEmpty) {
      final shouldRetry = _hasLengthFinishReason(data);
      if (shouldRetry && recentTurns.isNotEmpty) {
        final trimmedTurns = recentTurns.length > _retryTurnLimit
            ? recentTurns.sublist(recentTurns.length - _retryTurnLimit)
            : recentTurns;
        final retryMessages = <Map<String, String>>[
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'system', 'content': contextStr},
          ...trimmedTurns,
        ];
        final retryData = await _requestCompletion(retryMessages, apiKey);
        content = _extractAssistantText(retryData);
        if (content == null || content.trim().isEmpty) {
          debugPrint(
            'OpenAI empty assistant content. Raw response: ${_clip(jsonEncode(retryData), 4000)}',
          );
        }
      } else {
        debugPrint(
          'OpenAI empty assistant content. Raw response: ${_clip(jsonEncode(data), 4000)}',
        );
      }
    }

    return (content != null && content.trim().isNotEmpty)
        ? content.trim()
        : 'Kia ora - I am here. How can I help today?';
  }

  Future<Map<String, dynamic>> _requestCompletion(
    List<Map<String, String>> messages,
    String apiKey,
  ) async {
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'temperature': _temperature,
      'max_completion_tokens': _maxTokens,
      'reasoning_effort': _reasoningEffort,
    };

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
          .timeout(_requestTimeout);
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
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  bool _hasLengthFinishReason(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List) return false;
    for (final choice in choices) {
      if (choice is Map && choice['finish_reason'] == 'length') return true;
    }
    return false;
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
      'output_text',
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

  String _clip(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 1)}...';
  }
}
