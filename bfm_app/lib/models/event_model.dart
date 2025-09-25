/// ---------------------------------------------------------------------------
/// File: event_model.dart
/// Author: Luke Fraser-Brown
///
/// Minimal calendar/event model used for the "Upcoming Events" card.
/// Keep simple — expand later if you need recurrence rules or locations.
/// ---------------------------------------------------------------------------

class EventModel {
  final int? id;
  final String text;
  final String? icon;

  const EventModel({
    this.id,
    required this.text,
    this.icon,
  });

  factory EventModel.fromMap(Map<String, dynamic> m) {
    return EventModel(
      id: m['id'] as int?,
      text: (m['text'] ?? '') as String,
      icon: m['icon'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'text': text,
      'icon': icon,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }
}
