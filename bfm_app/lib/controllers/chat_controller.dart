import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/api/messages_api.dart';
import 'package:bfm_app/providers/api_providers.dart';

@immutable
class BackendChatState {
  final bool isSending;
  final String? error;
  final Map<String, dynamic>? lastResponse;

  const BackendChatState({
    this.isSending = false,
    this.error,
    this.lastResponse,
  });

  BackendChatState copyWith({
    bool? isSending,
    String? error,
    Map<String, dynamic>? lastResponse,
    bool clearError = false,
  }) {
    return BackendChatState(
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }
}

/// Controller for backend-proxied AI messages.
///
/// The existing [ChatScreen] talks directly to OpenAI. This controller wraps
/// the backend /messages endpoint as an alternative. The chat screen offers a
/// toggle between "local" (direct OpenAI) and "backend" (this).
class BackendChatController extends Notifier<BackendChatState> {
  late final MessagesApi _api;

  @override
  BackendChatState build() {
    _api = ref.watch(messagesApiProvider);
    return const BackendChatState();
  }

  Future<Map<String, dynamic>?> sendMessage(String message) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final payload = await _api.sendMessage(message);
      state = state.copyWith(isSending: false, lastResponse: payload);
      return payload;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return null;
    }
  }
}

final backendChatControllerProvider =
    NotifierProvider<BackendChatController, BackendChatState>(
        BackendChatController.new);
