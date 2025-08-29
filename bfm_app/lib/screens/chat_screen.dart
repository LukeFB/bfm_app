import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _messages = [
    _Message(
      text: "Kia ora! How can I help with your budget today?",
      isUser: false,
    ),
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text;
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _messages.add(
        _Message(
          text:
              "Great! I’ve added a savings goal for Textbooks — \$200 by the end of the semester. If you stick to \$20 a week, you’ll get there in 10 weeks.\n\n💡 Tip: set an automatic transfer for Mondays so you don’t even have to think about it.",
          isUser: false,
        ),
      );
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Moni AI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Bubble(
                    margin: const BubbleEdges.only(top: 10),
                    nip: msg.isUser
                        ? BubbleNip.rightBottom
                        : BubbleNip.leftBottom, // 👈 tail position
                    color: msg.isUser ? Colors.blue[200]! : bfmBeige,
                    child: Text(
                      msg.text,
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
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}
