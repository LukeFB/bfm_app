/// ---------------------------------------------------------------------------
/// File: lib/services/chat_storage.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   SharedPreferences-based chat history store.
///   - `loadMessages()` for the UI rolling window
///   - `loadAllMessages()` for context summarisation (capped larger)
///   - `saveMessages()` trims to max saved
///   - `clear()` for resetting the conversation
///
/// TODO:
///   - Tune _kMaxSavedAll to balance history vs storage
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bfm_app/models/chat_message.dart';

class ChatStorage {
  static const _kKey = 'moni_chat_messages_v1';

  // UI-visible trim (e.g., show last 100)
  static const _kMaxSavedUi = 100;

  // Larger cap for summariser to read (older history).
  static const _kMaxSavedAll = 300;

  Future<List<ChatMessage>> loadMessages() async {
    final all = await loadAllMessages();
    // Return last UI slice
    return all.takeLast(_kMaxSavedUi).toList();
  }

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

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    // Persist with larger cap; UI decides how much to show/send
    final trimmed = messages.takeLast(_kMaxSavedAll).toList();
    final jsonList = trimmed.map((m) => m.toJson()).toList();
    await prefs.setString(_kKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) {
    if (n <= 0) return const Iterable.empty();
    if (length <= n) return this;
    return sublist(length - n);
  }
}
