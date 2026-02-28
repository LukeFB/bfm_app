import 'package:dio/dio.dart';

import 'package:bfm_app/api/api_client.dart';

/// Backend AI messaging endpoint.
class MessagesApi {
  MessagesApi(this._client);
  final ApiClient _client;

  /// POST /messages (form-data) -> returns the AI response payload.
  Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await _client.dio.post(
      '/messages',
      data: FormData.fromMap({'message': message}),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'raw': data};
  }
}
