import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showRaw = false;

  String get _displayText {
    if (_showRaw && widget.message.rawContent?.isNotEmpty == true) {
      return widget.message.rawContent!;
    }
    if (widget.message.formattedContent?.isNotEmpty == true) {
      return widget.message.formattedContent!;
    }
    return widget.message.content;
  }

  @override
  Widget build(BuildContext context) {
    final msg    = widget.message;
    final isUser = msg.isFromUser;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical:   6,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.userBubble : AppColors.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: isUser ? 0 : 22),
                        child: SelectableText(
                          _displayText,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize:   15,
                            height:     1.45,
                            color:      isUser
                                ? AppColors.userBubbleText
                                : AppColors.aiBubbleText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(msg.timestamp),
                        style: const TextStyle(
                          fontFamily: 'DM Mono',
                          fontSize:   11,
                          color:      AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),

                  if (!isUser)
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _showRaw = !_showRaw),
                        child: Tooltip(
                          message: _showRaw ? 'Show formatted' : 'Show raw',
                          child: Icon(
                            _showRaw ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size:  16,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 180.ms).slideY(
              begin: 0.06,
              duration: 200.ms,
              curve: Curves.easeOutCubic,
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  isUser ? AppColors.accentDim : AppColors.surfaceElevated,
        border: Border.all(
          color: isUser
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        size:  16,
        color: isUser ? AppColors.accent : AppColors.textSecondary,
      ),
    );
  }
}