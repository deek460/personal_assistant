import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; // Requires flutter_markdown pkg
import '../../data/models/voice_chat_message.dart';

class VoiceMessageBubble extends StatefulWidget {
  final VoiceChatMessage message;

  const VoiceMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  _VoiceMessageBubbleState createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  // Flag to toggle debug view (raw text vs markdown)
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;

    // Determine what text to show
    final String content = (_showRaw && message.rawContent?.isNotEmpty == true)
        ? (message.rawContent ?? "")
        : (message.text);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // Align top for chat look
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.blue.withAlpha(220)
                        : Colors.grey.withAlpha(50),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                    ),
                  ),
                  child: isUser
                      ? Text(
                    content,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                      : _buildMarkdownContent(content),
                ),

                // Debug eye icon to toggle Raw/Formatted (Optional feature you had)
                if (!isUser)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _showRaw = !_showRaw),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          _showRaw ? Icons.visibility_off : Icons.visibility,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(String text) {
    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: Colors.black87, fontSize: 16),
        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        code: TextStyle(
          backgroundColor: Colors.grey.shade200,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      selectable: true,
    );
  }
}