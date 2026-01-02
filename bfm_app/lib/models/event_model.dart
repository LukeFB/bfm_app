/// ---------------------------------------------------------------------------
/// File: lib/models/event_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Event repository, dashboard service, and the Upcoming Events widget.
///
/// Purpose:
///   - Wraps event rows from SQLite/backend so UI code can focus on rendering.
///
/// Inputs:
///   - SQLite maps or network JSON.
///
/// Outputs:
///   - Dart model + serialisable map for persistence.
///
/// Notes:
///   - Add richer fields here if events gain more metadata.
/// ---------------------------------------------------------------------------

/// Lightweight event representation for dashboard surfaces.
class EventModel {
  final int? id;
  final int? backendId;
  final String title;
  final DateTime? endDate;
  final DateTime? updatedAt;

  const EventModel({
    this.id,
    this.backendId,
    required this.title,
    this.endDate,
    this.updatedAt,
  });

  /// Hydrates an event record from a map. Parses nullable ISO date strings while
  /// swallowing parsing errors.
  factory EventModel.fromMap(Map<String, dynamic> m) {
    DateTime? parse(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return EventModel(
      id: m['id'] as int?,
      backendId: m['backend_id'] as int?,
      title: (m['title'] ?? '') as String,
      endDate: parse(m['end_date']),
      updatedAt: parse(m['updated_at']),
    );
  }

  /// Serialises the model back to DB columns, using `DateTime.now()` as a
  /// fallback start time when no end date exists. Optionally includes the id.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'backend_id': backendId,
      'title': title,
      'end_date': endDate?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }
}
