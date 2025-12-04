import 'package:flutter/material.dart';
import '../../data/models/voice_chat_message.dart'; // Adjust import to your model location


class VoiceMessageBubble extends StatefulWidget {
  final VoiceChatMessage message;

  const VoiceMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  _VoiceMessageBubbleState createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    final displayedText = (_showRaw && message.rawContent?.isNotEmpty == true)
        ? message.rawContent!
        : (message.formattedContent?.isNotEmpty == true ? message.formattedContent! : message.text);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Colors.blue.withAlpha(200)
                        : Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    displayedText,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showRaw = !_showRaw;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showRaw ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
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
}
