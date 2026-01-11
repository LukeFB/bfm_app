/// ---------------------------------------------------------------------------
/// File: lib/screens/chat_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/chat` route via the bottom navigation.
///
/// Purpose:
///   - Chat UI that talks to Moni AI directly (no backend) while preserving
///     context between sessions.
///
/// Inputs:
///   - User-entered text, stored chat history, optional API key.
///
/// Outputs:
///   - Renders AI responses, persists conversation history, and surfaces helpful
///     errors if no key is configured.
/// ---------------------------------------------------------------------------

import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';

import 'package:bfm_app/models/chat_message.dart';
import 'package:bfm_app/repositories/referral_repository.dart';
import 'package:bfm_app/services/ai_client.dart';
import 'package:bfm_app/services/chat_storage.dart';
import 'package:bfm_app/services/api_key_store.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Top-level chat screen that wraps the Moni messenger UI.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Handles conversation state, persistence, and network calls.
class _ChatScreenState extends State<ChatScreen> {
  // Replaced _Message with ChatMessage to integrate with storage + AI.
  final List<ChatMessage> _messages = [];

  final TextEditingController _controller = TextEditingController();

  // scroll controller to keep view pinned to the latest messages.
  final ScrollController _scroll = ScrollController();

  // Services
  late final AiClient _ai;
  late final ChatStorage _store;

  // UI guards
  bool _sending = false;
  bool _hasApiKey = false;
  Map<String, String> _referralLinks = {};

  // How many most-recent turns to send with each request
  static const int kContextWindowTurns = 12;

  /// Sets up the AI + storage services and loads history.
  @override
  void initState() {
    super.initState();
    _ai = AiClient(); // pulls API key internally from ApiKeyStore
    _store = ChatStorage();
    _bootstrap();
  }

  /// Disposes controllers to avoid leaks.
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Loads persisted messages, seeds the greeting when empty, and checks if an
  /// API key exists so the UI can hint accordingly.
  Future<void> _bootstrap() async {
    // Load persisted messages (if any)
    final persisted = await _store.loadMessages();
    if (persisted.isNotEmpty) {
      setState(() {
        _messages.addAll(persisted);
      });
      // ensure the list is scrolled to bottom after loading history.
      _scrollToBottom();
    } else {
      // Seed welcome greeting
      _messages.add(ChatMessage.assistant(
        "Kia ora! How can I help with your budget today?",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      // scroll to the bottom after first paint.
      _scrollToBottom();
    }

    // Check if an API key is present (so we can optionally disable send)
    final key = await ApiKeyStore.get();
    setState(() {
      _hasApiKey = (key != null && key.isNotEmpty);
    });

    await _loadReferralLinks();
  }

  Future<void> _loadReferralLinks() async {
    try {
      final referrals = await ReferralRepository.getActive(limit: 100);
      final linkMap = <String, String>{};
      for (final ref in referrals) {
        final name = ref.organisationName?.trim();
        final website = ref.website?.trim();
        if (name?.isNotEmpty == true && website?.isNotEmpty == true) {
          linkMap[name!] = website!;
        }
      }
      if (!mounted) return;
      setState(() => _referralLinks = linkMap);
    } catch (_) {
      // Swallow errors; chat can still function without link expansion.
    }
  }

  /// Helper to jump the ListView to the bottom after the next frame.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Pushes the user message, sends it through AiClient, handles retries, and
  /// appends the assistant response (or an error bubble) while persisting both.
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
    _scrollToBottom(); // keep view pinned to newest message.

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
      final replyWithLinks = _injectReferralLinks(replyText);

      // Append assistant response and persist
      final botMsg = ChatMessage.assistant(replyWithLinks);
      _messages.add(botMsg);
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // scroll to bottom when bot replies.
    } catch (e) {
      // Friendly error bubble (keeps your style)
      _messages.add(ChatMessage.assistant(
        "Sorry, I couldn’t reply just now. ${_prettyErr(e)}",
      ));
      await _store.saveMessages(_messages);
      setState(() {});
      _scrollToBottom(); // maintain scroll position.
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }
  /// Clears history after a confirmation dialog and reseeds the greeting.
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
    await _store.clear();

    // reset UI to the default greeting
    _controller.clear();
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage.assistant('Kia ora! How can I help with your budget today?'));
    });

    // persist the single greeting message
    await _store.saveMessages(_messages);
    _scrollToBottom(); // scroll to top/bottom as needed after reset.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    }
  }

  /// Converts raw exceptions into user-friendly hints (e.g., missing API key).
  String _prettyErr(Object e) {
    final s = e.toString();
    if (s.contains('No API key') || s.contains('401')) {
      return "\n\nTip: Add your API key in Settings.";
    }
    // Surface the underlying error (trimmed) so users know what to fix.
    final trimmed = s.length > 180 ? '${s.substring(0, 177)}…' : s;
    return '\n\nError: $trimmed';
  }

  String _injectReferralLinks(String text) {
    if (_referralLinks.isEmpty) return text;
    var output = text;
    _referralLinks.forEach((name, url) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(name) + r'\b', caseSensitive: false);
      output = output.replaceFirstMapped(pattern, (match) {
        final start = match.start;
        if (start > 0 && match.input[start - 1] == '[') {
          return match.group(0)!; // already linked via markdown
        }
        final display = match.group(0)!;
        return '[$display]($url)';
      });
    });
    return output;
  }

  /// Renders chat history, the message composer, and clear/send controls.
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
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: const TextStyle(fontSize: 14),
                      ),
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
                    // allow Enter to send. TODO: not working
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
