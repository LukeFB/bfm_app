/// ---------------------------------------------------------------------------
/// File: lib/models/chat_message.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   Simple message model + JSON + OpenAI role mapping.
/// ---------------------------------------------------------------------------
enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  ChatMessage({required this.role, required this.content});

  factory ChatMessage.user(String s) => ChatMessage(role: ChatRole.user, content: s);
  factory ChatMessage.assistant(String s) => ChatMessage(role: ChatRole.assistant, content: s);

  Map<String, String> toOpenAiRoleContent() =>
      {'role': role == ChatRole.user ? 'user' : 'assistant', 'content': content};

  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: (j['role'] == 'user') ? ChatRole.user : ChatRole.assistant,
                  content: (j['content'] as String?) ?? '');
}
