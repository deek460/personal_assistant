import 'package:flutter/material.dart';
import '../../data/models/voice_chat_message.dart';

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
        crossAxisAlignment: CrossAxisAlignment.end, // Align latency to bottom
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
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Stack(
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
                    if (!message.isUser)
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
                              size: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // --- LATENCY DISPLAY ---
                if (!message.isUser && message.latency != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      "Latency: ${message.latency!.inMilliseconds}ms",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
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