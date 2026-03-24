import 'dart:io';
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
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [

                // --- IMAGE DISPLAY ---
                if (message.imagePath != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 220),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)
                        ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100, width: 100, color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),

                // --- TEXT BUBBLE ---
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // Using fully opaque colors ensures high contrast and readability
                        // even when the busy camera feed is playing in the background.
                          color: message.isUser
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)
                          ]
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
                              color: Colors.blue.shade700,
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
                        // Ensured text is somewhat readable on dark or light backgrounds
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}