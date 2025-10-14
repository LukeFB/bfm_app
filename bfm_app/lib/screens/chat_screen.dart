/// ---------------------------------------------------------------------------
/// File: lib/screens/chat_screen.dart
/// Author: Luke Fraser-Brown
///
/// High-level description:
///   Chat UI that calls Moni AI directly (no backend) and retains context.
///   - Keeps your existing Bubble styles, colors, layout, and send button.
///   - Loads/saves history locally so context survives restarts.
///   - Sends a rolling window of the last N turns + PRIVATE CONTEXT (budgets,
///     referrals, past-summary) assembled in AiClient/ContextBuilder.
///
/// Design philosophy:
///   - UI-only concerns live here.
///     -> Networking + prompt assembly in `AiClient`.
///     -> Persistence in `ChatStorage`.
///     -> Message model in `ChatMessage`.
///
/// Notes:
///   - If no API key is set, the input still renders; sending will show a
///     friendly error. You can also disable the send if you prefer.
///   - Does not remove or restyle your existing widgets.
/// ---------------------------------------------------------------------------

import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';

// Added imports
import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/services/ai_client.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/api_key_store.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Replaced _Message with ChatMessage to integrate with storage + AI.
  final List<ChatMessage> _messages = [];

  final TextEditingController _controller = TextEditingController();

  // Added: scroll controller to keep view pinned to the latest messages.
  final ScrollController _scroll = ScrollController();

  // Services
  late final AiClient _ai;
  late final ChatStorage _store;

  // UI guards
  bool _sending = false;
  bool _hasApiKey = false;

  // How many most-recent turns to send with each request
  static const int kContextWindowTurns = 12;

  @override
  void initState() {
    super.initState();
    _ai = AiClient(); // pulls API key internally from ApiKeyStore
    _store = ChatStorage();
    _bootstrap();
  }

  // Added: dispose controllers to avoid leaks.
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Load persisted messages (if any)
    final persisted = await _store.loadMessages();
    if (persisted.isNotEmpty) {
      setState(() {
        _messages.addAll(persisted);
      });
      // Added: ensure the list is scrolled to bottom after loading history.
      _scrollToBottom();
    } else {
      // Seed your existing greeting (same text as before)
      _messages.add(ChatMessage.assistant(
        "Kia ora! How can I help with your budget today?",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      // Added: scroll to the bottom after first paint.
      _scrollToBottom();
    }

    // Check if an API key is present (so we can optionally disable send)
    final key = await ApiKeyStore.get();
    setState(() {
      _hasApiKey = (key != null && key.isNotEmpty);
    });
  }

  // Added: helper to jump to end safely after a frame.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    // Append the user message to the UI and persist
    final userMsg = ChatMessage.user(text);
    _messages.add(userMsg);
    _controller.clear();
    await _store.saveMessages(_messages);
    setState(() {});
    _scrollToBottom(); // Added: keep view pinned to newest message.

    try {
      // Build a rolling window of the last N turns for the model
      final recent = _messages
          .sublist(
            _messages.length > kContextWindowTurns
                ? _messages.length - kContextWindowTurns
                : 0,
          )
          .map((m) => m.toOpenAiRoleContent())
          .toList();

      final replyText = await _ai.complete(recent);

      // Append assistant response and persist
      final botMsg = ChatMessage.assistant(replyText);
      _messages.add(botMsg);
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // Added: scroll to bottom when bot replies.
    } catch (e) {
      // Friendly error bubble (keeps your style)
      _messages.add(ChatMessage.assistant(
        "Sorry, I couldn’t reply just now. ${_prettyErr(e)}",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // Added: maintain scroll position.
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This will remove all messages for this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm != true) return;

    // wipe persisted history
    await _store.clear(); // make sure ChatStorage has a clear() method (we added earlier)

    // reset UI to the default greeting
    _controller.clear();
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage.assistant('Kia ora! How can I help with your budget today?'));
    });

    // persist the single greeting message
    await _store.saveMessages(_messages);
    _scrollToBottom(); // Added: scroll to top/bottom as needed after reset.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    }
  }

  String _prettyErr(Object e) {
    final s = e.toString();
    // Give a short hint if key is missing
    if (s.contains('No API key') || s.contains('401')) {
      return "\n\nTip: Add your API key in Settings.";
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // keep your background color
      appBar: AppBar(
        title: const Text("Moni AI"),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline),
            onPressed: _sending ? null : _clearChat, // disabled while sending
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scroll, // Added: keep a handle for auto-scroll.
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == ChatRole.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Bubble(
                    margin: const BubbleEdges.only(top: 10),
                    nip: isUser
                        ? BubbleNip.rightBottom
                        : BubbleNip.leftBottom, // tail position
                    color: isUser ? Colors.blue[200]! : bfmBeige,
                    child: Text(
                      msg.content, // keep Text (no style change)
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 4), // spacing between bubbles
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // Added: allow Enter to send.
                    onSubmitted: (_) {
                      if (_hasApiKey && !_sending) _sendMessage();
                    },
                    // Hint shows a gentle nudge if no key is present
                    decoration: InputDecoration(
                      hintText: _hasApiKey
                          ? "Type a message..."
                          : "Type a message... (Add API key in Settings)",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  // If you prefer to hard-disable without a key, change to:
                  // onPressed: _hasApiKey && !_sending ? _sendMessage : null,
                  // Changed: disable send button when no key is present or when sending.
                  onPressed: (_hasApiKey && !_sending) ? _sendMessage : null, // Added: guard on API key.
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
