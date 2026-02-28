/// ---------------------------------------------------------------------------
/// File: lib/models/onboarding_response.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Value object capturing all onboarding data collected during the
///     registration flow, structured for submission to the backend API.
///
/// Backend payload shape (JSON):
/// ```json
/// {
///   "registration": {
///     "first_name": "Jane",
///     "last_name": "Doe",
///     "email": "jane@example.com",
///     "phone": "+6421123456",
///     "date_of_birth": "1995-03-15"
///   },
///   "referrer_token": "WL-ABC123",
///   "account_setup": {
///     "income_frequency": "fortnightly",
///     "primary_goal": "save_more",
///     "currency": "NZD"
///   },
///   "akahu_connected": true,
///   "completed_at": "2026-02-25T10:30:00Z"
/// }
/// ```
/// ---------------------------------------------------------------------------

class OnboardingRegistration {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? dateOfBirth;

  const OnboardingRegistration({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.dateOfBirth,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth,
      };

  factory OnboardingRegistration.fromJson(Map<String, dynamic> json) =>
      OnboardingRegistration(
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
      );

  bool get isValid =>
      (firstName?.trim().isNotEmpty ?? false) &&
      (lastName?.trim().isNotEmpty ?? false) &&
      (email?.trim().isNotEmpty ?? false);
}

class OnboardingAccountSetup {
  final String? incomeFrequency;
  final String? primaryGoal;

  const OnboardingAccountSetup({
    this.incomeFrequency,
    this.primaryGoal,
  });

  Map<String, dynamic> toJson() => {
        'income_frequency': incomeFrequency,
        'primary_goal': primaryGoal,
      };

  factory OnboardingAccountSetup.fromJson(Map<String, dynamic> json) =>
      OnboardingAccountSetup(
        incomeFrequency: json['income_frequency'] as String?,
        primaryGoal: json['primary_goal'] as String?,
      );
}

class OnboardingResponse {
  final OnboardingRegistration registration;
  final String? referrerToken;
  final OnboardingAccountSetup accountSetup;
  final bool akahuConnected;
  final String? completedAt;

  const OnboardingResponse({
    this.registration = const OnboardingRegistration(),
    this.referrerToken,
    this.accountSetup = const OnboardingAccountSetup(),
    this.akahuConnected = false,
    this.completedAt,
  });

  /// Full backend-ready payload.
  Map<String, dynamic> toJson() => {
        'registration': registration.toJson(),
        'referrer_token': referrerToken,
        'account_setup': accountSetup.toJson(),
        'akahu_connected': akahuConnected,
        'completed_at': completedAt,
      };

  factory OnboardingResponse.fromJson(Map<String, dynamic> json) {
    final regJson = json['registration'];
    final setupJson = json['account_setup'];

    return OnboardingResponse(
      registration: regJson is Map<String, dynamic>
          ? OnboardingRegistration.fromJson(regJson)
          : const OnboardingRegistration(),
      referrerToken: json['referrer_token'] as String?,
      accountSetup: setupJson is Map<String, dynamic>
          ? OnboardingAccountSetup.fromJson(setupJson)
          : const OnboardingAccountSetup(),
      akahuConnected: json['akahu_connected'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
    );
  }

  bool get hasAnswers => toDisplayMap().isNotEmpty;

  Map<String, String> toDisplayMap() {
    final map = <String, String>{};

    void add(String label, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        map[label] = trimmed;
      }
    }

    add('Name', [registration.firstName, registration.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' '));
    add('Email', registration.email);
    add('Phone', registration.phone);
    add('Date of birth', registration.dateOfBirth);
    add('Referrer token', referrerToken);
    add('Income frequency', accountSetup.incomeFrequency);
    add('Primary goal', accountSetup.primaryGoal);
    return map;
  }
}
