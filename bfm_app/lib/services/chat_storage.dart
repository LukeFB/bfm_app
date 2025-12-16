/// ---------------------------------------------------------------------------
/// File: lib/services/chat_storage.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Chat screen, AI client, and context builders when saving or loading
///     conversation history.
///
/// Purpose:
///   - Provides a SharedPreferences-backed rolling log of chat messages with
///     separate caps for UI vs LLM context.
///
/// Inputs:
///   - Lists of `ChatMessage` objects.
///
/// Outputs:
///   - Persisted JSON blobs and trimmed message lists.
///
/// Notes:
///   - TODO: tune `_kMaxSavedAll` to balance history vs storage.
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bfm_app/models/chat_message.dart';

/// Handles persistence of chat message history in SharedPreferences.
class ChatStorage {
  static const _kKey = 'moni_chat_messages_v1';

  // UI-visible trim (e.g., show last 100)
  static const _kMaxSavedUi = 100;

  // Larger cap for summariser to read (older history).
  static const _kMaxSavedAll = 300;

  /// Loads the recent slice shown in the UI (trimmed to `_kMaxSavedUi`).
  Future<List<ChatMessage>> loadMessages() async {
    final all = await loadAllMessages();
    // Return last UI slice
    return all.takeLast(_kMaxSavedUi).toList();
  }

  /// Loads the full stored history (trimmed to `_kMaxSavedAll`) for summary
  /// contexts. Handles JSON decode failures defensively.
  Future<List<ChatMessage>> loadAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      return list.takeLast(_kMaxSavedAll).toList();
    } catch (_) {
      return [];
    }
  }

  /// Persists the provided messages after trimming to the "all history" cap.
  Future<void> saveMessages(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    // Persist with larger cap; UI decides how much to show/send
    final trimmed = messages.takeLast(_kMaxSavedAll).toList();
    final jsonList = trimmed.map((m) => m.toJson()).toList();
    await prefs.setString(_kKey, jsonEncode(jsonList));
  }

  /// Deletes every stored message, used for reset buttons.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

extension _TakeLast<T> on List<T> {
  /// Returns at most the last `n` items from a list. Avoids allocating when
  /// the list is already short.
  Iterable<T> takeLast(int n) {
    if (n <= 0) return const Iterable.empty();
    if (length <= n) return this;
    return sublist(length - n);
  }
}
