class TipModel {
  final int? id;
  final int? backendId;
  final String title;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  const TipModel({
    this.id,
    this.backendId,
    required this.title,
    this.expiresAt,
    this.updatedAt,
  });

  factory TipModel.fromMap(Map<String, dynamic> data) {
    DateTime? parse(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return TipModel(
      id: data['id'] as int?,
      backendId: data['backend_id'] as int?,
      title: (data['title'] ?? '') as String,
      expiresAt: parse(data['expires_at']),
      updatedAt: parse(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'backend_id': backendId,
      'title': title,
      'body': '',
      'priority': 0,
      'is_active': 1,
      'expires_at': expiresAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }
}
