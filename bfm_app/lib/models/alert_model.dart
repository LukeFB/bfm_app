/// ---------------------------------------------------------------------------
/// File: alert_model.dart
/// Author: Luke Fraser-Brown
///
/// Minimal model for alerts. Alerts may be
/// recurring bills or potentially admin created.
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
