/// ---------------------------------------------------------------------------
/// File: lib/models/onboarding_response.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Lightweight value object that captures the optional onboarding answers
///     we ask new Moni users for (age, gender, etc).
///   - Keeps serialization logic in one place so storage layers stay simple.
///
/// Notes:
///   - Every field is optional to prevent onboarding friction.
/// ---------------------------------------------------------------------------

class OnboardingResponse {
  final String? age;
  final String? gender;
  final String? location;
  final String? referrer;
  final String? mainReason;
  final String? situation;

  const OnboardingResponse({
    this.age,
    this.gender,
    this.location,
    this.referrer,
    this.mainReason,
    this.situation,
  });

  /// Serialises the object into a JSON-friendly map for persistence.
  Map<String, dynamic> toJson() => {
    'age': age,
    'gender': gender,
    'location': location,
    'referrer': referrer,
    'mainReason': mainReason,
    'situation': situation,
  };

  /// Rehydrates an instance from stored JSON.
  factory OnboardingResponse.fromJson(Map<String, dynamic> json) =>
      OnboardingResponse(
        age: json['age'] as String?,
        gender: json['gender'] as String?,
        location: json['location'] as String?,
        referrer: json['referrer'] as String?,
        mainReason: json['mainReason'] as String?,
        situation: json['situation'] as String?,
      );

  /// Returns true when at least one optional answer is present.
  bool get hasAnswers => toDisplayMap().isNotEmpty;

  /// Friendly labels for UI/prompts with only the non-empty values included.
  Map<String, String> toDisplayMap() {
    final map = <String, String>{};

    void add(String label, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        map[label] = trimmed;
      }
    }

    add('Age', age);
    add('Gender', gender);
    add('Location', location);
    add('Referrer', referrer);
    add('Main reason', mainReason);
    add('Situation', situation);
    return map;
  }
}
