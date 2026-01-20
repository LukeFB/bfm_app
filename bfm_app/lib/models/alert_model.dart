// ---------------------------------------------------------------------------
// File: lib/models/alert_model.dart
// Author: Luke Fraser-Brown
//
// Called by:
//   - Alert repository + dashboard widgets that surface callouts to the user.
//
// Purpose:
//   - Typed view over the `alerts` table so services can reason about IDs,
//     text, and icons without juggling raw maps.
//
// Inputs:
//   - Raw SQLite rows or JSON objects.
//
// Outputs:
//   - Dart objects plus `Map<String, dynamic>` payloads for inserts/updates.
// ---------------------------------------------------------------------------

/// Represents a short alert message that can include an optional icon.
class AlertModel {
  final int? id;
  final String title;
  final String? message;
  final String? icon; // emoji or asset name
  final int? recurringTransactionId;
  final double? amount;
  final DateTime? dueDate;
  final int leadTimeDays;
  final bool isActive;
  final String? createdAt;

  const AlertModel({
    this.id,
    required this.title,
    this.message,
    this.icon,
    this.recurringTransactionId,
    this.amount,
    this.dueDate,
    this.leadTimeDays = 3,
    this.isActive = true,
    this.createdAt,
  });

  AlertModel copyWith({
    int? id,
    String? title,
    String? message,
    String? icon,
    int? recurringTransactionId,
    double? amount,
    DateTime? dueDate,
    int? leadTimeDays,
    bool? isActive,
    String? createdAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      recurringTransactionId:
          recurringTransactionId ?? this.recurringTransactionId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Rehydrates an alert from a database row or decoded JSON payload.
  factory AlertModel.fromMap(Map<String, dynamic> m) {
    return AlertModel(
      id: m['id'] as int?,
      title: (m['title'] ?? '') as String,
      message: m['message'] as String?,
      icon: m['icon'] as String?,
      recurringTransactionId: m['recurring_transaction_id'] as int?,
      amount: (m['amount'] as num?)?.toDouble(),
      dueDate: m['due_date'] != null && (m['due_date'] as String).isNotEmpty
          ? DateTime.tryParse(m['due_date'] as String)
          : null,
      leadTimeDays: (m['lead_time_days'] as num?)?.toInt() ?? 3,
      isActive: (m['is_active'] as num?)?.toInt() != 0,
      createdAt: m['created_at'] as String?,
    );
  }

  /// Serialises the alert back to a map for inserts/updates. Optionally includes
  /// the primary key when performing updates.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'title': title,
      'message': message,
      'icon': icon,
      'recurring_transaction_id': recurringTransactionId,
      'amount': amount,
      'due_date': dueDate?.toIso8601String(),
      'lead_time_days': leadTimeDays,
      'is_active': isActive ? 1 : 0,
    };
    if (includeId && id != null) m['id'] = id;
    if (createdAt != null) m['created_at'] = createdAt;
    return m;
  }
}
