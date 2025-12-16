/// ---------------------------------------------------------------------------
/// File: lib/models/category_model.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Category repository, budget builders, and analytics services whenever
///     a category row needs to be read or written.
///
/// Purpose:
///   - Strongly typed view of a category row including Akahu mapping metadata.
///
/// Inputs:
///   - SQLite maps or network payloads containing Akahu IDs.
///
/// Outputs:
///   - Dart objects plus serialised maps for persistence.
/// ---------------------------------------------------------------------------

/// Represents a budgeting category and optional usage stats.
class CategoryModel {
  final int? id;
  final String name;
  // Optional
  final String? icon; // emoji or resource name
  final String? color; // hex color as string (e.g. "#FFEEAA")
  final String? akahuCategoryId; // external mapping

  // Optional bookkeeping
  final int? usageCount;
  final String? firstSeenAt;
  final String? lastUsedAt;

  const CategoryModel({
    this.id,
    required this.name,
    this.icon,
    this.color,
    this.akahuCategoryId,
    this.usageCount,
    this.firstSeenAt,
    this.lastUsedAt,
  });

  /// Recreates a category from a database row. Handles optional usage metadata.
  factory CategoryModel.fromMap(Map<String, dynamic> m) {
    return CategoryModel(
      id: m['id'] as int?,
      name: (m['name'] ?? '') as String,
      icon: m['icon'] as String?,
      color: m['color'] as String?,
      akahuCategoryId: m['akahu_category_id'] as String?,
      usageCount: (m['usage_count'] as num?)?.toInt(),
      firstSeenAt: m['first_seen_at'] as String?,
      lastUsedAt: m['last_used_at'] as String?,
    );
  }

  /// Serialises this category for inserts/updates. Usage timestamps are
  /// included only when already known.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'name': name,
      'icon': icon,
      'color': color,
      'akahu_category_id': akahuCategoryId,
      if (usageCount != null) 'usage_count': usageCount,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }
}

