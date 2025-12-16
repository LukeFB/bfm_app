/// ---------------------------------------------------------------------------
/// File: lib/models/referral_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Plain-Dart model for referral rows stored locally in SQLite.
///
/// Called by:
///   `referral_repository.dart` for CRUD work and `content_sync_service.dart`
///   when mapping backend sync payloads.
///
/// Inputs / Outputs:
///   Translates between raw DB maps and strongly typed values with
///   nullable fields that match the backend schema.
/// ---------------------------------------------------------------------------
class ReferralModel {
  final int? id;
  final int? backendId;
  final String? organisationName;
  final String? category;
  final String? website;
  final String? phone;
  final String? services;
  final String? demographics;
  final String? availability;
  final String? email;
  final String? address;
  final String? region;
  final String? notes;
  final bool isActive;
  final DateTime? updatedAt;

  /// Creates an immutable referral in memory. Optional named params align
  /// with our SQLite columns so repositories can hydrate objects easily.
  const ReferralModel({
    this.id,
    this.backendId,
    this.organisationName,
    this.category,
    this.website,
    this.phone,
    this.services,
    this.demographics,
    this.availability,
    this.email,
    this.address,
    this.region,
    this.notes,
    this.isActive = true,
    this.updatedAt,
  });

  /// Builds a referral from a SQLite row or API map.
  /// - Safely parses nullable DateTimes.
  /// - Coerces `is_active` ints into booleans.
  /// Anything unexpected falls back to `null` so UI code can handle absence.
  factory ReferralModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return ReferralModel(
      id: data['id'] as int?,
      backendId: data['backend_id'] as int?,
      organisationName: data['organisation_name'] as String?,
      category: data['category'] as String?,
      website: data['website'] as String?,
      phone: data['phone'] as String?,
      services: data['services'] as String?,
      demographics: data['demographics'] as String?,
      availability: data['availability'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      region: data['region'] as String?,
      notes: data['notes'] as String?,
      isActive: (data['is_active'] as int? ?? 1) == 1,
      updatedAt: parseDate(data['updated_at']),
    );
  }

  /// Converts the model back into a map for inserts/updates.
  /// - Handles optional `id` inclusion for updates vs inserts.
  /// - Persists booleans and DateTimes in the formats expected by SQLite.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'backend_id': backendId,
      'organisation_name': organisationName,
      'category': category,
      'website': website,
      'phone': phone,
      'services': services,
      'demographics': demographics,
      'availability': availability,
      'email': email,
      'address': address,
      'region': region,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }
}
