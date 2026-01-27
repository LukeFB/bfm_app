/// ---------------------------------------------------------------------------
/// File: lib/models/asset_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Represents a user-entered asset (cash, car, property, etc.).
///   - Used by the savings screen to display total net worth from manual assets.
///
/// Called by:
///   - `AssetRepository` for persistence.
///   - `SavingsService` for aggregation.
///   - `SavingsScreen` for display.
/// ---------------------------------------------------------------------------

/// Categories of assets users can track.
enum AssetCategory {
  cash,
  vehicle,
  property,
  investment,
  kiwisaver,
  valuables,
  other;

  /// Display name for the UI.
  String get displayName {
    switch (this) {
      case AssetCategory.cash:
        return 'Cash';
      case AssetCategory.vehicle:
        return 'Vehicle';
      case AssetCategory.property:
        return 'Property';
      case AssetCategory.investment:
        return 'Investment';
      case AssetCategory.kiwisaver:
        return 'KiwiSaver';
      case AssetCategory.valuables:
        return 'Valuables';
      case AssetCategory.other:
        return 'Other';
    }
  }

  /// Icon name for the UI.
  String get iconName {
    switch (this) {
      case AssetCategory.cash:
        return 'account_balance_wallet';
      case AssetCategory.vehicle:
        return 'directions_car';
      case AssetCategory.property:
        return 'home';
      case AssetCategory.investment:
        return 'trending_up';
      case AssetCategory.kiwisaver:
        return 'elderly';
      case AssetCategory.valuables:
        return 'diamond';
      case AssetCategory.other:
        return 'category';
    }
  }

  /// Parse from database string.
  static AssetCategory fromString(String? value) {
    if (value == null) return AssetCategory.other;
    return AssetCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AssetCategory.other,
    );
  }
}

/// Model representing a user-entered asset.
class AssetModel {
  final int? id;
  final String name;
  final AssetCategory category;
  final double value;
  final String? notes;
  final DateTime? updatedAt;

  const AssetModel({
    this.id,
    required this.name,
    required this.category,
    required this.value,
    this.notes,
    this.updatedAt,
  });

  /// Creates a copy with updated fields.
  AssetModel copyWith({
    int? id,
    String? name,
    AssetCategory? category,
    double? value,
    String? notes,
    DateTime? updatedAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts to a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category.name,
      'value': value,
      'notes': notes,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Creates from a database row.
  factory AssetModel.fromMap(Map<String, dynamic> map) {
    return AssetModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Asset',
      category: AssetCategory.fromString(map['category'] as String?),
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }
}
