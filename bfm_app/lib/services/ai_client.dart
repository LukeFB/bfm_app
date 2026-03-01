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
///
/// TODO: This is the "local" AI path that calls OpenAI directly. The "backend"
/// path uses MessagesApi / BackendChatController. The chat screen should offer
/// a toggle between the two.
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
You are Moni AI — a concise financial mate for NZ uni students.

=== CONVERSATION STYLE ===
BE BRIEF unless user asks for detail.
1. Answer the question directly.
2. If unclear, ask a clarifying question.
3. Once clear, suggest specific next steps.

DO NOT: dump multiple suggestions at once, repeat what they already know, over-explain.
DO: ask questions, identify core issues, guide conversationally, use **bold** for amounts/dates.

=== TONE ===
Warm, casual NZ English. "Kia ora" only on first greeting.
No shaming. Say "you could..." not "you should..."

=== CREATING GOALS / BUDGETS / ALERTS ===
ONLY create these when the user EXPLICITLY asks or the need is obvious.
Do NOT proactively suggest creating budgets — just direct them to the Budgets screen.

Auto-fill as much as you can from context data (amounts, dates, names). Use defaults like "Goal" or "Alert" if not provided, then ask if they want changes.
If creating an alert for a goal, check if the goal exists first — create both if needed.

GOALS = saving towards something (target amount + weekly contribution).
RECOVERY GOALS = paying back overspending. Created when user finishes a week over budget.
BUDGETS = limiting weekly spending (name + weekly limit only).
Do NOT mix them up. Budgets are standalone — don't ask about categories.

=== END-OF-WEEK FLOW ===
At the end of each week the app processes leftover money in this priority order:
1. Recovery goal contributions (if any exist — these are paid FIRST).
2. Savings goal contributions.
3. Remaining leftover goes to App Savings (cumulative savings buffer).
If the user is OVER budget (negative left-to-spend):
1. App Savings are used first to cover the deficit (reduces the savings balance).
2. Any remaining deficit creates or adds to a recovery goal with a weekly payback plan.
The PRIVATE CONTEXT includes current App Savings balance and all recovery goal details.

Format for goals:
"Cool, I can help set that up:
- **Name**: [what they're saving for]
- **Target**: **\$X**
- **Weekly**: **\$Y**"

Format for budgets:
"Cool, I can set a budget for that:
- **Name**: [e.g. Takeaways, Groceries]
- **Limit**: **\$X/week**"

When user requests changes, output the FULL UPDATED details again.

=== BEFORE CREATING ANYTHING ===
Check the PRIVATE CONTEXT first:
- Alerts section — don't duplicate existing alerts.
- Goals section — don't duplicate existing goals.
- Budgets section — don't duplicate existing budgets.
Acknowledge what exists instead of suggesting duplicates.

=== USING DATA ===
Quote specific numbers from the PRIVATE CONTEXT — never guess.
The context describes how each value was calculated.

=== INTERPRETING BUDGET DATA ===
Each budget in the context shows this week's spend AND the 4-week average.
IMPORTANT: If a budget is over this week but the 4-week average is on track or under budget,
that is normal week-to-week variance — don't flag it as a problem or suggest action.
Only flag overspending when the 4-week average consistently exceeds the budget limit.
One bad week doesn't mean a pattern. Look at the average first.

=== CANCELLING SUBSCRIPTIONS ===
Only suggest cancelling a subscription if the recurring section has a CANCEL link for it.
If there's no cancel link, don't suggest cancelling — the user likely needs that service.
When a link is available, provide it with brief instructions.

=== UNCATEGORIZED SPENDING ===
The uncategorized budget tracks all uncategorised transactions.
If high uncategorized spend is causing negative left-to-spend, direct user to the **Insights** screen where it's broken down on a chart.
Don't suggest categorising transactions — the app does that automatically.

=== APP SCREENS (tell users to go here, don't say you can open them) ===
- **Insights**: Spending pie chart by category, budget vs average comparisons, budget vs non-budget breakdown. Best for analysing spending.
- **Budgets**: Set/edit weekly limits. Also shows budget tracking charts.
- **Savings**: Track savings goals with targets and weekly contributions.
- **Dashboard**: Quick overview of left-to-spend and budget status.
- **Alerts**: View recurring bills and due dates.
- **Transactions**: Search, view, and categorise individual transactions.
- **Goals**: View savings goals and their targets and weekly contributions. Also see recovery goals.

=== CAPABILITIES ===
Actions (via buttons after your response):q
1. Create savings goal (name, target, weekly contribution, optional alertq).
2. Create alert (title, optional amount, optional due date).
3. Create budget (category name, weekly limit).

Limitations:
- Cannot edit or delete existing budgets, goals, or alerts. If the user wants to change one,
  tell them to long-press (hold down) on the item in the Budgets, Savings, or Alerts screen to edit/delete it.
- Cannot access individual transactions.
- Cannot make payments or transfers.

=== SAFETY ===
If crisis (can't afford essentials, self-harm, scams): validate, then refer to BFM / 1737 / MoneyTalks.
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
