import 'package:dio/dio.dart';

import 'package:bfm_app/api/api_client.dart';

/// Auth endpoints: login, register, me.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  /// POST /auth/login (form-data) -> returns access_token string.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/auth/login',
      data: FormData.fromMap({'email': email, 'password': password}),
    );
    return _extractToken(response.data);
  }

  /// POST /auth/register (form-data) -> returns access_token string.
  ///
  /// Required: [email], [password], [passwordConfirmation], [firstName].
  /// Optional: [lastName], [phone], [dateOfBirth], [incomeFrequency],
  ///           [primaryGoal], [referrerToken].
  Future<String> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
    String? incomeFrequency,
    String? primaryGoal,
    dynamic referrerToken,
  }) async {
    final fields = <String, dynamic>{
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty)
        'date_of_birth': dateOfBirth,
      if (incomeFrequency != null && incomeFrequency.isNotEmpty)
        'income_frequency': incomeFrequency,
      if (primaryGoal != null && primaryGoal.isNotEmpty)
        'primary_goal': primaryGoal,
      if (referrerToken != null) 'referrer_token': referrerToken,
    };

    final response = await _client.dio.post(
      '/auth/register',
      data: FormData.fromMap(fields),
    );
    return _extractToken(response.data);
  }

  /// GET /auth/me -> returns the current user payload.
  Future<Map<String, dynamic>> me() async {
    final response = await _client.dio.get('/auth/me');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'raw': data};
  }

  String _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final token = data['access_token'];
      if (token is String && token.isNotEmpty) return token;
    }
    throw Exception('No access_token in response');
  }
}
