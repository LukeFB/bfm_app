/// ---------------------------------------------------------------------------
/// File: event_model.dart
/// Author: Luke Fraser-Brown
///
/// Minimal calendar/event model used for the "Upcoming Events" card.
/// Keep simple — expand later if you need recurrence rules or locations.
/// ---------------------------------------------------------------------------

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

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'backend_id': backendId,
      'title': title,
      'start_date': (endDate ?? DateTime.now()).toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }
}
