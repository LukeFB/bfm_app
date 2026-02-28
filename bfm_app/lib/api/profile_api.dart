import 'package:dio/dio.dart';

import 'package:bfm_app/api/api_client.dart';

/// Profile endpoints.
class ProfileApi {
  ProfileApi(this._client);
  final ApiClient _client;

  /// POST /profile/onboarding (JSON body).
  ///
  /// Expected keys: first_name, last_name, phone, date_of_birth,
  /// income_frequency, primary_goal, referrer_token.
  Future<void> onboarding(Map<String, dynamic> payload) async {
    await _client.dio.post(
      '/profile/onboarding',
      data: payload,
    );
  }

  /// GET /profile/organisations -> list of organisations the user belongs to.
  Future<List<Map<String, dynamic>>> organisations() async {
    final response = await _client.dio.get('/profile/organisations');
    return _extractList(response.data);
  }

  /// POST /profile/join (form-data) -> join an organisation by referral code.
  Future<Map<String, dynamic>> joinOrganisation(String referralCode) async {
    final response = await _client.dio.post(
      '/profile/join',
      data: FormData.fromMap({'referral_code': referralCode}),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'raw': data};
  }

  /// DELETE /profile/organisations/:id -> leave an organisation.
  Future<void> leaveOrganisation(int organisationId) async {
    await _client.dio.delete('/profile/organisations/$organisationId');
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['items'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
