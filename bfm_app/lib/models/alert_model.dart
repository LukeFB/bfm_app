/// ---------------------------------------------------------------------------
/// File: alert_model.dart
/// Author: Luke Fraser-Brown
///
/// Minimal model for one-off alerts. Alerts may be system-generated
/// (recurring bills) or admin-created. Keep Alerts simple to allow
/// agenda-like UI rendering.
/// ---------------------------------------------------------------------------

class AlertModel {
  final int? id;
  final String text;
  final String? icon; // emoji or asset name

  const AlertModel({
    this.id,
    required this.text,
    this.icon,
  });

  factory AlertModel.fromMap(Map<String, dynamic> m) {
    return AlertModel(
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
