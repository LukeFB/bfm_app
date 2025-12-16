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

  /// Create a message with a specific role + content.
  ChatMessage({required this.role, required this.content});

  /// Convenience constructors to make usages more readable.
  factory ChatMessage.user(String s) =>
      ChatMessage(role: ChatRole.user, content: s);

  factory ChatMessage.assistant(String s) =>
      ChatMessage(role: ChatRole.assistant, content: s);

  /// Converts this message to OpenAI's `{role, content}` schema.
  Map<String, String> toOpenAiRoleContent() =>
      {'role': role == ChatRole.user ? 'user' : 'assistant', 'content': content};

  /// Serialises to JSON for local persistence (role name + content).
  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};

  /// Hydrates from JSON stored on disk. Defaults to assistant role/content if
  /// the payload is malformed so downstream code never crashes.
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
      role: (j['role'] == 'user') ? ChatRole.user : ChatRole.assistant,
      content: (j['content'] as String?) ?? '');
}
