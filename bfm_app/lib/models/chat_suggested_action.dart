import 'dart:convert';

/// Types of follow-up actions the assistant can suggest after a chat turn.
enum ChatActionType { goal, budget, alert }

/// Structured representation of an action that can be confirmed inside the UI.
class ChatSuggestedAction {
  final ChatActionType type;
  final String? title;
  final String? description;
  final double? amount;
  final double? weeklyAmount;
  final String? categoryName;
  final DateTime? dueDate;
  final int? dueInDays;
  final String? note;

  const ChatSuggestedAction({
    required this.type,
    this.title,
    this.description,
    this.amount,
    this.weeklyAmount,
    this.categoryName,
    this.dueDate,
    this.dueInDays,
    this.note,
  });

  /// Human-readable fallback title for chips/cards.
  String get displayLabel {
    return title?.trim().isNotEmpty == true
        ? title!.trim()
        : categoryName?.trim().isNotEmpty == true
            ? categoryName!.trim()
            : _titleForType(type);
  }

  bool get hasDueDate => dueDate != null || (dueInDays ?? 0) > 0;

  ChatSuggestedAction copyWith({
    ChatActionType? type,
    String? title,
    String? description,
    double? amount,
    double? weeklyAmount,
    String? categoryName,
    DateTime? dueDate,
    int? dueInDays,
    String? note,
  }) {
    return ChatSuggestedAction(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      weeklyAmount: weeklyAmount ?? this.weeklyAmount,
      categoryName: categoryName ?? this.categoryName,
      dueDate: dueDate ?? this.dueDate,
      dueInDays: dueInDays ?? this.dueInDays,
      note: note ?? this.note,
    );
  }

  factory ChatSuggestedAction.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] ?? json['action']);
    if (type == null) {
      throw ArgumentError('Unknown chat action type: ${json['type']}');
    }
    return ChatSuggestedAction(
      type: type,
      title: _string(json['title']) ?? _string(json['name']),
      description: _string(json['description']) ?? _string(json['reason']),
      amount: _double(json['amount'] ?? json['goal_amount']),
      weeklyAmount: _double(
        json['weekly_amount'] ??
            json['weekly_limit'] ??
            json['weekly_contribution'],
      ),
      categoryName:
          _string(json['category']) ?? _string(json['category_name']),
      dueDate: _parseDate(json['due_date'] ?? json['dueDate']),
      dueInDays: _int(json['due_in_days'] ?? json['dueInDays']),
      note: _string(json['note']) ?? _string(json['notes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (weeklyAmount != null) 'weekly_amount': weeklyAmount,
      if (categoryName != null) 'category': categoryName,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (dueInDays != null) 'due_in_days': dueInDays,
      if (note != null) 'note': note,
    };
  }

  static List<ChatSuggestedAction> listFromDynamic(dynamic payload) {
    if (payload == null) return const [];
    if (payload is String) {
      var text = payload.trim();
      if (text.isEmpty) return const [];
      if (text.startsWith('```')) {
        text = text.replaceFirst(RegExp(r'^```(?:json)?'), '');
        text = text.replaceFirst(RegExp(r'```$'), '');
        text = text.trim();
      }
      final arrayMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(text);
      if (arrayMatch != null) {
        text = arrayMatch.group(0)!;
      }
      try {
        final decoded = jsonDecode(text);
        return listFromDynamic(decoded);
      } catch (_) {
        return const [];
      }
    }
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .map(ChatSuggestedAction.fromJson)
          .toList();
    }
    if (payload is Map) {
      return [ChatSuggestedAction.fromJson(payload.cast<String, dynamic>())];
    }
    return const [];
  }

  static String _titleForType(ChatActionType type) {
    switch (type) {
      case ChatActionType.goal:
        return 'Savings goal';
      case ChatActionType.budget:
        return 'Budget';
      case ChatActionType.alert:
        return 'Alert';
    }
  }

  static ChatActionType? _parseType(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim().toLowerCase();
    switch (text) {
      case 'goal':
      case 'saving':
      case 'savings_goal':
        return ChatActionType.goal;
      case 'budget':
        return ChatActionType.budget;
      case 'alert':
      case 'reminder':
        return ChatActionType.alert;
    }
    return null;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed =
        double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9\.\-]'), ''));
    return parsed;
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9\-]'), ''));
    return parsed;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
