import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'package:flutter/services.dart'; // still available if needed elsewhere

/// MessageBubble now supports a local toggle to switch between raw and formatted text.
/// Tapping the small toggle icon flips the displayed text between message.rawContent
/// and message.formattedContent (falls back to message.content when either is null).
class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  // Local toggle: when true show raw content if available, otherwise show formatted/content.
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final displayed = _computeDisplayedText(message);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Row(
        mainAxisAlignment:
        message.isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.assistant,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppConstants.smallPadding),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: AppConstants.smallPadding,
              ),
              decoration: BoxDecoration(
                color: message.isFromUser
                    ? AppColors.userMessageBg
                    : AppColors.assistantMessageBg,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Stack(
                children: [
                  // Message content + timestamp
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        displayed,
                        style: TextStyle(
                          color: message.isFromUser
                              ? AppColors.messageText
                              : AppColors.assistantMessageText,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: (message.isFromUser
                              ? AppColors.messageText
                              : AppColors.assistantMessageText)
                              .withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Small toggle button in top-right of bubble for non-user messages
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildToggleButton(message),
                  ),
                ],
              ),
            ),
          ),

          if (message.isFromUser) ...[
            const SizedBox(width: AppConstants.smallPadding),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary,
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _computeDisplayedText(ChatMessage message) {
    // If toggle is set and raw available -> raw
    if (_showRaw && (message.rawContent != null && message.rawContent!.isNotEmpty)) {
      return message.rawContent!;
    }

    // Otherwise prefer formatted if available, else content
    if (message.formattedContent != null && message.formattedContent!.isNotEmpty) {
      return message.formattedContent!;
    }

    return message.content;
  }

  Widget _buildToggleButton(ChatMessage message) {
    // Show toggle only for assistant responses (optional). If desired, show for all.
    if (message.isFromUser == true) {
      // for user bubbles return a small placeholder to keep layout consistent
      return const SizedBox.shrink();
    }

    // Icon changes visually when in raw mode
    final icon = _showRaw ? Icons.visibility_off : Icons.visibility;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showRaw = !_showRaw;
        });

        // Optional: small haptic feedback
        // HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
