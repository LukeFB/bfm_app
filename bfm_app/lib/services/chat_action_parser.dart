/// Pure text-parsing utilities for the chat screen's action detection.
///
/// Extracted from chat_screen.dart to keep UI and NLP logic separate.
/// Every function here is stateless — it takes input and returns a result
/// with no dependency on widget state or BuildContext.

import 'dart:convert';

import 'package:bfm_app/models/chat_suggested_action.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/utils/format_helpers.dart';

// ---------------------------------------------------------------------------
// Action label / lookup helpers
// ---------------------------------------------------------------------------

String inlineActionLabel(ChatSuggestedAction action) {
  final amount = action.amount ?? action.weeklyAmount;
  final amountLabel =
      amount != null && amount > 0 ? '${formatCurrency(amount)} ' : '';
  switch (action.type) {
    case ChatActionType.goal:
      return 'Create ${amountLabel}goal';
    case ChatActionType.budget:
      return 'Create ${amountLabel}budget';
    case ChatActionType.alert:
      return 'Create ${amountLabel}alert';
  }
}

ChatSuggestedAction? firstActionOfType(
  ChatActionType type,
  List<ChatSuggestedAction> actions,
) {
  for (final action in actions) {
    if (action.type == type) return action;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Auto-naming for new goals / alerts / budgets
// ---------------------------------------------------------------------------

Future<String> nextGoalName() async {
  final goals = await GoalRepository.getAll();
  return nextIndexedName('Goal', goals.map((g) => g.name));
}

Future<String> nextAlertName() async {
  final alerts = await AlertRepository.getAll();
  return nextIndexedName('Alert', alerts.map((a) => a.title));
}

Future<String> nextBudgetName() async {
  final budgets = await BudgetRepository.getAll();
  final labels = budgets
      .where((b) => b.goalId == null)
      .map((b) => b.label ?? '');
  return nextIndexedName('Budget', labels);
}

String nextIndexedName(String base, Iterable<String?> names) {
  final pattern = RegExp('^${RegExp.escape(base)}\\s*(\\d+)\$',
      caseSensitive: false);
  var maxIndex = 0;
  for (final name in names) {
    if (name == null) continue;
    final match = pattern.firstMatch(name.trim());
    if (match == null) continue;
    final value = int.tryParse(match.group(1)!);
    if (value != null && value > maxIndex) {
      maxIndex = value;
    }
  }
  return '$base ${maxIndex + 1}';
}

// ---------------------------------------------------------------------------
// Prefill helper
// ---------------------------------------------------------------------------

String prefillAmount(double? value) {
  if (value == null || value <= 0) return '';
  final decimals = value >= 100 ? 0 : 2;
  return value.toStringAsFixed(decimals);
}

// ---------------------------------------------------------------------------
// Intent classification
// ---------------------------------------------------------------------------

bool mentionsBill(String text) {
  final pattern =
      RegExp(r'\b(bill(?:s)?|invoice|repair|mechanic|dentist|fine|payment|rent|warrant|wof|rego)\b');
  return pattern.hasMatch(text);
}

bool mentionsAlert(String text) {
  final pattern =
      RegExp(r'\b(alert|remind|reminder|notify|notification|remember)\b');
  return pattern.hasMatch(text);
}

bool mentionsGoal(String text) {
  final pattern = RegExp(
    r'\b(goal|saving|save up|savings|save for|set aside|put aside|contribute|target)\b',
  );
  return pattern.hasMatch(text);
}

bool mentionsBudget(String text) {
  final pattern = RegExp(r'\b(budget|weekly limit|spend limit)\b');
  return pattern.hasMatch(text);
}

bool wantsAlertOnly(String text) {
  return mentionsAlert(text) && !mentionsGoal(text);
}

bool goalNeedsAlert(String normalizedText, List<ChatSuggestedAction> actions) {
  if (!mentionsGoal(normalizedText)) return false;
  final hasTimeline = extractDueInDaysFromText(normalizedText) != null ||
      extractDueDateFromText(normalizedText) != null;
  if (hasTimeline) return true;
  for (final action in actions) {
    if (action.type == ChatActionType.goal && action.hasDueDate) return true;
  }
  return false;
}

bool assistantPromptedAction(String text, ChatActionType type) {
  if (text.isEmpty) return false;
  switch (type) {
    case ChatActionType.goal:
      return RegExp(
        r'\b(create goal|goal name|call this goal|name this goal|goal)\b',
      ).hasMatch(text);
    case ChatActionType.budget:
      return RegExp(r'\b(create budget|budget name|weekly limit|budget)\b')
          .hasMatch(text);
    case ChatActionType.alert:
      return RegExp(r'\b(create alert|remind|reminder|alert)\b')
          .hasMatch(text);
  }
}

// ---------------------------------------------------------------------------
// Name extraction
// ---------------------------------------------------------------------------

bool looksLikeName(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(lower)) return false;
  if (RegExp(r'\b(in\s+)?\d+\s*(day|days|week|weeks|month|months)\b')
      .hasMatch(lower)) {
    return false;
  }
  if (lower.contains('today') ||
      lower.contains('tomorrow') ||
      lower.contains('next week') ||
      lower.contains('next month')) {
    return false;
  }
  if (trimmed.split(RegExp(r'\s+')).length > 6) return false;
  return RegExp(r'[a-zA-Z]').hasMatch(trimmed);
}

String? extractGoalNameFromText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return null;
  final namedMatch = RegExp(
    r'\b(?:called|named|name it|call it)\s+([a-z0-9][a-z0-9\s\-&]+)\b',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (namedMatch != null) {
    final raw = normalized.substring(namedMatch.start, namedMatch.end);
    final cleaned = raw
        .replaceFirst(
          RegExp(
            r'\b(?:called|named|name it|call it)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final title = cleanGoalTitle(cleaned);
    return title.isEmpty ? null : title;
  }
  final forMatch = RegExp(
    r'\b(?:for|to buy|to get|to save for|to pay for)\s+([a-z0-9][a-z0-9\s\-&]+)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (forMatch != null) {
    final raw = normalized.substring(forMatch.start, forMatch.end);
    final cleaned = raw
        .replaceFirst(
          RegExp(
            r'\b(?:for|to buy|to get|to save for|to pay for)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final title = cleanGoalTitle(cleaned);
    return title.isEmpty ? null : title;
  }
  if (looksLikeName(normalized)) {
    return cleanGoalTitle(normalized);
  }
  return null;
}

String cleanGoalTitle(String text) {
  var cleaned = text.trim();
  cleaned = cleaned.replaceAll(RegExp(r'[\.\!\?]+$'), '').trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  return cleaned;
}

// ---------------------------------------------------------------------------
// Action title normalization
// ---------------------------------------------------------------------------

ChatSuggestedAction normalizeActionTitle(ChatSuggestedAction action) {
  final rawTitle = action.title?.trim();
  if (rawTitle == null || rawTitle.isEmpty) return action;
  switch (action.type) {
    case ChatActionType.goal:
      if (isGenericGoalName(rawTitle)) {
        return action.copyWith(title: 'goal');
      }
      break;
    case ChatActionType.alert:
      if (isGenericAlertName(rawTitle)) {
        return action.copyWith(title: 'alert');
      }
      break;
    case ChatActionType.budget:
      if (isGenericBudgetName(rawTitle)) {
        return action.copyWith(title: 'budget');
      }
      break;
  }
  return action;
}

List<ChatSuggestedAction> normalizeActionTitles(
  List<ChatSuggestedAction> actions,
  String? userText,
) {
  if (actions.isEmpty) return actions;
  return actions
      .map((action) => normalizeTitleForAction(action, userText))
      .toList();
}

ChatSuggestedAction normalizeTitleForAction(
  ChatSuggestedAction action,
  String? userText,
) {
  final rawTitle = action.title?.trim();
  final typeWord = action.type.name;
  if (rawTitle == null || rawTitle.isEmpty) {
    return action.copyWith(title: typeWord);
  }
  final lowerTitle = rawTitle.toLowerCase();
  if (isGenericTypeLabel(lowerTitle, typeWord)) {
    return action.copyWith(title: typeWord);
  }
  final hasTypeWord =
      RegExp(r'\b' + RegExp.escape(typeWord) + r'\b').hasMatch(lowerTitle);
  final userNamed = userProvidedExplicitName(userText, action.type);
  if (hasTypeWord && !userNamed) {
    return action.copyWith(title: typeWord);
  }
  return action;
}

bool isGenericGoalName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return isGenericTypeLabel(normalized, 'goal') ||
      normalized == 'savings goal' ||
      normalized == 'upcoming bill';
}

bool isGenericAlertName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return isGenericTypeLabel(normalized, 'alert') || normalized == 'reminder';
}

bool isGenericBudgetName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return isGenericTypeLabel(normalized, 'budget');
}

bool isGenericTypeLabel(String normalized, String typeWord) {
  return normalized == typeWord;
}

bool userProvidedExplicitName(String? text, ChatActionType type) {
  if (text == null || text.trim().isEmpty) return false;
  final normalized = text.toLowerCase();
  final namePhrases = [
    r'\bcall it\b',
    r'\bname it\b',
    r'\blabel it\b',
    r'\btitle it\b',
    r'\bcalled\b',
    r'\bnamed\b',
  ];
  for (final phrase in namePhrases) {
    if (RegExp(phrase).hasMatch(normalized)) {
      return true;
    }
  }
  final typeWord = type.name;
  if (RegExp(r'\b' + RegExp.escape(typeWord) + r'\b').hasMatch(normalized) &&
      (normalized.contains('called') || normalized.contains('named'))) {
    return true;
  }
  if (type == ChatActionType.alert) {
    if (RegExp(r'\breminder\b').hasMatch(normalized) &&
        (normalized.contains('called') || normalized.contains('named'))) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Amount / date / timeline extraction
// ---------------------------------------------------------------------------

double? extractAmountFromText(String text) {
  final cleaned = text.replaceAll(',', '');
  final matches = RegExp(r'(\$)?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*([kK])?')
      .allMatches(cleaned);
  for (final match in matches) {
    final value = double.tryParse(match.group(2) ?? '');
    if (value == null || value <= 0) continue;
    final suffix = match.group(3);
    final hasCurrency = match.group(1) != null;

    if (!hasCurrency && value >= 2000 && value <= 2099 && value == value.truncate()) {
      continue;
    }

    final tail = cleaned.substring(match.end).toLowerCase();
    final hasTimeUnit = RegExp(r'^\s*(day|days|week|weeks|month|months|year|years)\b')
        .hasMatch(tail);
    if (hasTimeUnit && !hasCurrency) {
      continue;
    }

    if (RegExp(r'^\s*[-/]\s*\d').hasMatch(tail)) {
      continue;
    }

    final beforeMatch = match.start > 0 ? cleaned.substring(0, match.start).toLowerCase() : '';
    if (RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}[-/])\s*$').hasMatch(beforeMatch)) {
      continue;
    }

    final amount = suffix == null ? value : value * 1000;
    return amount;
  }
  return null;
}

int? extractDueInDaysFromText(String text) {
  final normalized = text.toLowerCase();
  final dayMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(day|days)\b').firstMatch(normalized);
  if (dayMatch != null) {
    final days = int.tryParse(dayMatch.group(1)!);
    if (days != null && days >= 0) return days;
  }
  final weekMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(week|weeks)\b').firstMatch(normalized);
  if (weekMatch != null) {
    final weeks = int.tryParse(weekMatch.group(1)!);
    if (weeks != null && weeks >= 0) return weeks * 7;
  }
  final monthMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(month|months)\b').firstMatch(normalized);
  if (monthMatch != null) {
    final months = int.tryParse(monthMatch.group(1)!);
    if (months != null && months >= 0) return months * 30;
  }
  final yearMatch =
      RegExp(r'\b(?:in\s+)?(\d{1,3})\s*(year|years)\b').firstMatch(normalized);
  if (yearMatch != null) {
    final years = int.tryParse(yearMatch.group(1)!);
    if (years != null && years >= 0) return years * 365;
  }
  if (normalized.contains('tomorrow')) return 1;
  if (normalized.contains('today')) return 0;
  if (normalized.contains('next week')) return 7;
  if (normalized.contains('next month')) return 30;
  return null;
}

DateTime? extractDueDateFromText(String text) {
  final normalized = text.toLowerCase();
  final isoMatch =
      RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(normalized);
  if (isoMatch != null) {
    try {
      return DateTime.parse(isoMatch.group(0)!);
    } catch (_) {
      // fall through
    }
  }
  final monthMatch = RegExp(
    r'\b(\d{1,2})\s+'
    r'(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|september|oct|october|nov|november|dec|december)'
    r'(?:\s+(\d{4}))?\b',
  ).firstMatch(normalized);
  if (monthMatch != null) {
    final day = int.tryParse(monthMatch.group(1)!);
    final year = int.tryParse(monthMatch.group(3) ?? '');
    final monthText = monthMatch.group(2)!;
    final month = monthNumber(monthText);
    if (day != null && month != null) {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      var candidate = DateTime(targetYear, month, day);
      if (candidate.isBefore(now) && year == null) {
        candidate = DateTime(targetYear + 1, month, day);
      }
      return candidate;
    }
  }
  return null;
}

int? monthNumber(String text) {
  switch (text.substring(0, 3)) {
    case 'jan': return 1;
    case 'feb': return 2;
    case 'mar': return 3;
    case 'apr': return 4;
    case 'may': return 5;
    case 'jun': return 6;
    case 'jul': return 7;
    case 'aug': return 8;
    case 'sep': return 9;
    case 'oct': return 10;
    case 'nov': return 11;
    case 'dec': return 12;
  }
  return null;
}

double? calculateWeeklyContribution(
  double amount, {
  DateTime? dueDate,
  int? dueInDays,
}) {
  int? days = dueInDays;
  if (days == null && dueDate != null) {
    days = dueDate.difference(DateTime.now()).inDays;
  }
  if (days == null || days <= 0) return null;
  final weeks = (days / 7).clamp(1, double.infinity);
  final weekly = amount / weeks;
  return (weekly * 100).roundToDouble() / 100;
}

double? firstAmount(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.amount != null && action.amount! > 0) {
      return action.amount;
    }
  }
  return null;
}

DateTime? firstDueDate(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.dueDate != null) {
      return action.dueDate;
    }
  }
  return null;
}

int? firstDueInDays(List<ChatSuggestedAction> actions) {
  for (final action in actions) {
    if (action.dueInDays != null) {
      return action.dueInDays;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Assistant text extraction (for structured AI responses)
// ---------------------------------------------------------------------------

/// Extracts weekly limit from structured assistant response.
double? extractLimitFromAssistant(String text) {
  final cleaned = text.replaceAll('**', '');
  final patterns = [
    RegExp(r'limit[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)(?:\s*/?\s*week)?', caseSensitive: false),
    RegExp(r'cap\s+(?:at|of)[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'\$([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:/|per\s+)?week\s+limit', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0 && !(value >= 2000 && value <= 2099)) {
        return value;
      }
    }
  }
  return null;
}

/// Extracts target/goal amount from structured assistant response.
double? extractTargetFromAssistant(String text) {
  final cleaned = text.replaceAll('**', '');
  final patterns = [
    RegExp(r'target[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'amount[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'goal[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'sav(?:e|ing)[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0 && !(value >= 2000 && value <= 2099 && value == value.truncate())) {
        return value;
      }
    }
  }
  return null;
}

/// Extracts weekly contribution from structured assistant response.
double? extractWeeklyFromAssistant(String text) {
  final cleaned = text.replaceAll('**', '');
  final patterns = [
    RegExp(r'weekly[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'weekly contribution[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    RegExp(r'contribute[:\s]+\$?([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:per\s+)?week', caseSensitive: false),
    RegExp(r'\$([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:/|per\s+)?week', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0) return value;
    }
  }
  return null;
}

/// Extracts a name from structured assistant response.
String? extractNameFromAssistant(String text) {
  final cleaned = text.replaceAll('**', '');
  final patterns = [
    RegExp(r'name[:\s]+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+target|\s+amount)', caseSensitive: false),
    RegExp(r'called\s+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+for)', caseSensitive: false),
    RegExp(r'goal[:\s]+([A-Za-z][A-Za-z0-9\s\-]+?)(?:\s*[-,\n]|\s*$|\s+target)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      var name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty && name.length < 30) {
        name = name.replaceAll(RegExp(r'[,.\-]+$'), '').trim();
        final lower = name.toLowerCase();
        if (lower != 'goal' && lower != 'savings' && lower != 'alert' && lower != 'budget' && lower != 'set') {
          return name;
        }
      }
    }
  }
  return null;
}

/// Creates actions from structured patterns in assistant text (Name/Target/Limit/etc.).
List<ChatSuggestedAction> extractActionsFromAssistantText(String text) {
  final actions = <ChatSuggestedAction>[];
  final cleaned = text.replaceAll('**', '').toLowerCase();

  final hasGoalPattern = cleaned.contains('name:') &&
      (cleaned.contains('target:') || cleaned.contains('weekly:'));

  if (hasGoalPattern) {
    final name = extractNameFromAssistant(text);
    final amount = extractTargetFromAssistant(text) ?? extractAmountFromText(text);
    final weekly = extractWeeklyFromAssistant(text);
    final dueDate = extractDueDateFromText(text);
    final dueInDays = extractDueInDaysFromText(text);

    if (name != null || amount != null) {
      actions.add(ChatSuggestedAction(
        type: ChatActionType.goal,
        title: name,
        amount: amount,
        weeklyAmount: weekly,
      ));

      final mentionsAlertText = cleaned.contains('alert') || cleaned.contains('reminder');
      if (dueDate != null || dueInDays != null || mentionsAlertText) {
        var alertDueInDays = dueInDays;
        if (dueDate == null && alertDueInDays == null) {
          if (amount != null && weekly != null && weekly > 0) {
            final weeks = (amount / weekly).ceil();
            alertDueInDays = weeks * 7;
          } else {
            alertDueInDays = 28;
          }
        }

        actions.add(ChatSuggestedAction(
          type: ChatActionType.alert,
          title: name ?? 'Reminder',
          amount: amount,
          dueDate: dueDate,
          dueInDays: alertDueInDays,
        ));
      }
    }
  }

  final hasBudgetPattern = cleaned.contains('limit:') && !cleaned.contains('target:');

  if (hasBudgetPattern && actions.isEmpty) {
    final name = extractNameFromAssistant(text);
    final limit = extractLimitFromAssistant(text) ?? extractAmountFromText(text);

    if (name != null || limit != null) {
      actions.add(ChatSuggestedAction(
        type: ChatActionType.budget,
        title: name,
        categoryName: name,
        weeklyAmount: limit,
      ));
    }
  }

  final hasAlertPattern = (cleaned.contains('alert') || cleaned.contains('reminder')) &&
      cleaned.contains('due');

  if (hasAlertPattern && actions.isEmpty) {
    final name = extractNameFromAssistant(text);
    final amount = extractAmountFromText(text);
    final dueDate = extractDueDateFromText(text);
    final dueInDays = extractDueInDaysFromText(text);

    if (name != null || dueDate != null || dueInDays != null) {
      actions.add(ChatSuggestedAction(
        type: ChatActionType.alert,
        title: name,
        amount: amount,
        dueDate: dueDate,
        dueInDays: dueInDays,
      ));
    }
  }

  return actions;
}

/// Returns true when the assistant's reply contains structured action patterns
/// that warrant showing action chips.
bool shouldDetectActions(String userMessage, String assistantReply) {
  final cleaned = assistantReply.replaceAll('**', '').toLowerCase();
  return cleaned.contains('name:') ||
      cleaned.contains('target:') ||
      cleaned.contains('weekly:') ||
      cleaned.contains('limit:') ||
      cleaned.contains('amount:') ||
      cleaned.contains('due:');
}

/// Enhances extracted actions (e.g. adds timeline-based alerts to goals).
List<ChatSuggestedAction> enhanceActions(
  List<ChatSuggestedAction> actions, {
  String? userText,
  String? assistantText,
  String? actionContext,
}) {
  if (actions.isEmpty) return actions;

  var result = List<ChatSuggestedAction>.from(actions);

  final hasGoal = result.any((a) => a.type == ChatActionType.goal);
  final hasAlert = result.any((a) => a.type == ChatActionType.alert);

  if (hasGoal && !hasAlert) {
    final extractedDueInDays = userText != null ? extractDueInDaysFromText(userText) : null;
    final extractedDueDate = userText != null ? extractDueDateFromText(userText) : null;
    final hasTimeline = extractedDueInDays != null || extractedDueDate != null;

    final assistantDueInDays = assistantText != null ? extractDueInDaysFromText(assistantText) : null;
    final assistantDueDate = assistantText != null ? extractDueDateFromText(assistantText) : null;
    final assistantHasTimeline = assistantDueInDays != null || assistantDueDate != null;

    final mentionsAlertText = (userText?.toLowerCase().contains('alert') ?? false) ||
        (userText?.toLowerCase().contains('reminder') ?? false) ||
        (assistantText?.toLowerCase().contains('alert') ?? false) ||
        (assistantText?.toLowerCase().contains('reminder') ?? false);

    if (hasTimeline || assistantHasTimeline || mentionsAlertText) {
      final goal = result.firstWhere((a) => a.type == ChatActionType.goal);
      final dueDate = extractedDueDate ?? assistantDueDate;
      var dueInDays = extractedDueInDays ?? assistantDueInDays;

      if (dueDate == null && dueInDays == null) {
        final target = goal.amount;
        final weekly = goal.weeklyAmount;
        if (target != null && weekly != null && weekly > 0) {
          final weeks = (target / weekly).ceil();
          dueInDays = weeks * 7;
        } else {
          dueInDays = 28;
        }
      }

      result.add(ChatSuggestedAction(
        type: ChatActionType.alert,
        title: goal.title ?? 'Reminder',
        description: userText ?? '',
        amount: goal.amount,
        dueDate: dueDate,
        dueInDays: dueInDays,
      ));
    }
  }

  return result;
}

/// Fills in missing action data (amount, weekly, title, dates) by extracting
/// from both assistant and user text.
List<ChatSuggestedAction> prefillMissingActionData(
  List<ChatSuggestedAction> actions, {
  String? userText,
  String? assistantText,
}) {
  if (actions.isEmpty) return actions;

  final assistantAmount = assistantText != null
      ? (extractTargetFromAssistant(assistantText) ?? extractAmountFromText(assistantText))
      : null;
  final assistantWeekly = assistantText != null ? extractWeeklyFromAssistant(assistantText) : null;
  final assistantName = assistantText != null ? extractNameFromAssistant(assistantText) : null;
  final assistantDueInDays = assistantText != null ? extractDueInDaysFromText(assistantText) : null;
  final assistantDueDate = assistantText != null ? extractDueDateFromText(assistantText) : null;

  final userAmount = userText != null ? extractAmountFromText(userText) : null;
  final userName = userText != null ? extractGoalNameFromText(userText) : null;
  final userDueInDays = userText != null ? extractDueInDaysFromText(userText) : null;
  final userDueDate = userText != null ? extractDueDateFromText(userText) : null;

  return actions.map((action) {
    var updated = action;

    if (updated.amount == null) {
      final amount = assistantAmount ?? userAmount;
      if (amount != null) {
        updated = updated.copyWith(amount: amount);
      }
    }

    if (updated.type == ChatActionType.goal && updated.weeklyAmount == null) {
      if (assistantWeekly != null && assistantWeekly > 0) {
        updated = updated.copyWith(weeklyAmount: assistantWeekly);
      } else if (updated.amount != null) {
        final dueIn = updated.dueInDays ?? assistantDueInDays ?? userDueInDays;
        final dueDate = updated.dueDate ?? assistantDueDate ?? userDueDate;
        final weekly = calculateWeeklyContribution(
          updated.amount!,
          dueDate: dueDate,
          dueInDays: dueIn,
        );
        if (weekly != null && weekly > 0) {
          updated = updated.copyWith(weeklyAmount: weekly);
        }
      }
    }

    if (updated.type == ChatActionType.goal &&
        (updated.title == null || isGenericGoalName(updated.title!))) {
      final name = assistantName ?? userName;
      if (name != null) {
        updated = updated.copyWith(title: name);
      }
    }

    if (updated.dueDate == null) {
      final date = assistantDueDate ?? userDueDate;
      if (date != null) {
        updated = updated.copyWith(dueDate: date);
      }
    }

    if (updated.dueInDays == null) {
      final days = assistantDueInDays ?? userDueInDays;
      if (days != null) {
        updated = updated.copyWith(dueInDays: days);
      }
    }

    return updated;
  }).toList();
}

/// Pulls the assistant text out of a backend JSON response.
String extractBackendMessage(Map<String, dynamic> response) {
  const keys = ['message', 'content', 'response', 'data', 'raw'];
  for (final key in keys) {
    if (!response.containsKey(key)) continue;
    final value = response[key];
    final text = resolveTextValue(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

/// Recursively resolves a value to a plain-text string.
String resolveTextValue(dynamic value) {
  if (value == null) return '';
  if (value is String) {
    if (value.trimLeft().startsWith('{')) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map<String, dynamic>) {
          return extractBackendMessage(parsed);
        }
      } catch (_) {}
    }
    return value.trim();
  }
  if (value is Map) {
    const nested = ['message', 'content', 'text', 'response', 'data'];
    for (final k in nested) {
      if (value.containsKey(k)) {
        final inner = resolveTextValue(value[k]);
        if (inner.isNotEmpty) return inner;
      }
    }
  }
  if (value is List && value.isNotEmpty) {
    return resolveTextValue(value.first);
  }
  return '';
}

