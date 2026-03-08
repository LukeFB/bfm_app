/// ---------------------------------------------------------------------------
/// File: lib/models/chat_message.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Tiny chat message model shared between storage, context builder, and
///   the AI client.
///
/// Called by:
///   `chat_screen.dart`, `chat_storage.dart`, `context_builder.dart`.
///
/// Inputs / Outputs:
///   Wraps content + role and exposes helpers to convert to/from JSON and the
///   OpenAI chat API format.
/// ---------------------------------------------------------------------------
/// Who is speaking in a chat message.
enum ChatRole { user, assistant }

/// Immutable chat message with helpers for serialisation.
class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime? timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.user(String s) =>
      ChatMessage(role: ChatRole.user, content: s);

  factory ChatMessage.assistant(String s) =>
      ChatMessage(role: ChatRole.assistant, content: s);

  Map<String, String> toOpenAiRoleContent() =>
      {'role': role == ChatRole.user ? 'user' : 'assistant', 'content': content};

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    DateTime? ts;
    if (j['timestamp'] is String) {
      ts = DateTime.tryParse(j['timestamp'] as String);
    }
    return ChatMessage(
      role: (j['role'] == 'user') ? ChatRole.user : ChatRole.assistant,
      content: (j['content'] as String?) ?? '',
      timestamp: ts,
    );
  }
}
