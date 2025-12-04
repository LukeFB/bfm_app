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
