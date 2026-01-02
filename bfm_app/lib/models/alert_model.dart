/// ---------------------------------------------------------------------------
/// File: lib/models/alert_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Alert repository + dashboard widgets that surface callouts to the user.
///
/// Purpose:
///   - Typed view over the `alerts` table so services can reason about IDs,
///     text, and icons without juggling raw maps.
///
/// Inputs:
///   - Raw SQLite rows or JSON objects.
///
/// Outputs:
///   - Dart objects plus `Map<String, dynamic>` payloads for inserts/updates.
/// ---------------------------------------------------------------------------

/// Represents a short alert message that can include an optional icon.
class AlertModel {
  final int? id;
  final String title;
  final String? message;
  final String? icon; // emoji or asset name
  final int? recurringTransactionId;
  final int leadTimeDays;
  final bool isActive;
  final String? createdAt;

  const AlertModel({
    this.id,
    required this.title,
    this.message,
    this.icon,
    this.recurringTransactionId,
    this.leadTimeDays = 3,
    this.isActive = true,
    this.createdAt,
  });

  /// Rehydrates an alert from a database row or decoded JSON payload.
  factory AlertModel.fromMap(Map<String, dynamic> m) {
    return AlertModel(
      id: m['id'] as int?,
      title: (m['title'] ?? '') as String,
      message: m['message'] as String?,
      icon: m['icon'] as String?,
      recurringTransactionId: m['recurring_transaction_id'] as int?,
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
      'lead_time_days': leadTimeDays,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }
}
