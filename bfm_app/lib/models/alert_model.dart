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
  final String text;
  final String? icon; // emoji or asset name

  const AlertModel({
    this.id,
    required this.text,
    this.icon,
  });

  /// Rehydrates an alert from a database row or decoded JSON payload.
  factory AlertModel.fromMap(Map<String, dynamic> m) {
    return AlertModel(
      id: m['id'] as int?,
      text: (m['text'] ?? '') as String,
      icon: m['icon'] as String?,
    );
  }

  /// Serialises the alert back to a map for inserts/updates. Optionally includes
  /// the primary key when performing updates.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'text': text,
      'icon': icon,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }
}
