/// ---------------------------------------------------------------------------
/// File: category_model.dart
/// Author: Luke Fraser-Brown
///

/// ---------------------------------------------------------------------------
/// File: category_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Domain model for expense/income categories (Food, Rent, Bills, etc).
///   Maps to `categories` table and may be populated from Akahu enrichment
///   categories when available.
///
/// Notes:
///   - Keep visual hints (icon, color) in the model so UI components can
///     render self-contained category chips/cards.
///   - `akahuCategoryId` is optional: store it only if you want to reconcile
///     or periodically refresh Akahu's category labels.
/// ---------------------------------------------------------------------------

class CategoryModel {
  final int? id;
  final String name;
  final String? icon; // emoji or resource name
  final String? color; // hex color as string (e.g. "#FFEEAA")
  final String? akahuCategoryId; // external mapping (optional)

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

