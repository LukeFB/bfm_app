import 'package:dio/dio.dart';

import 'package:bfm_app/api/api_client.dart';

/// Backend AI messaging endpoint.
class MessagesApi {
  MessagesApi(this._client);
  final ApiClient _client;

  /// POST /messages (form-data) -> returns the AI response payload.
  ///
  /// [userContext] is an optional string of private financial context
  /// (built by ContextBuilder) that the backend can inject into the AI prompt.
  Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? userContext,
  }) async {
    final fields = <String, dynamic>{'message': message};
    if (userContext != null && userContext.isNotEmpty) {
      fields['user_context'] = userContext;
    }
    final response = await _client.dio.post(
      '/messages',
      data: FormData.fromMap(fields),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'raw': data};
  }
}
