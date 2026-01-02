/// ---------------------------------------------------------------------------
/// File: lib/models/tip_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents a short dashboard tip pulled from the backend CMS.
///
/// Called by:
///   `tip_repository.dart`, `dashboard_service.dart`, and dashboard UI widgets.
///
/// Inputs / Outputs:
///   Converts SQLite rows to typed objects and back. Also stores expiry info so
///   dashboard can hide stale tips.
/// ---------------------------------------------------------------------------
class TipModel {
  final int? id;
  final int? backendId;
  final String title;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  /// Immutable tip with optional backend link + timestamps.
  const TipModel({
    this.id,
    this.backendId,
    required this.title,
    this.expiresAt,
    this.updatedAt,
  });

  /// Hydrates a tip from a SQLite row. Parses ISO timestamps defensively.
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

  /// Serialises the tip into a DB map, filling optional CMS fields with
  /// defaults the dashboard expects today.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'backend_id': backendId,
      'title': title,
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
