import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/voice_chat_message.dart';

class VoiceMessageBubble extends StatefulWidget {
  final VoiceChatMessage message;

  const VoiceMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;

    final displayText = (_showRaw && msg.rawContent?.isNotEmpty == true)
        ? msg.rawContent!
        : (msg.formattedContent?.isNotEmpty == true ? msg.formattedContent! : msg.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Image attachment
                if (msg.imagePath != null)
                  _ImageAttachment(path: msg.imagePath!)
                      .animate().fadeIn(duration: 200.ms),

                // Bubble
                _Bubble(
                  displayText: displayText,
                  isUser:      isUser,
                  showRaw:     _showRaw,
                  onToggleRaw: () => setState(() => _showRaw = !_showRaw),
                ).animate().fadeIn(duration: 180.ms).slideY(
                  begin: 0.08,
                  duration: 220.ms,
                  curve: Curves.easeOutCubic,
                ),

                // Latency
                if (!isUser && msg.latency != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      '${msg.latency!.inMilliseconds}ms',
                      style: const TextStyle(
                        fontFamily:  'DM Mono',
                        fontSize:    10,
                        color:       AppColors.textDisabled,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  isUser ? AppColors.accentDim : AppColors.surfaceElevated,
        border: Border.all(
          color: isUser ? AppColors.accent.withValues(alpha: 0.4) : AppColors.surfaceBorder,
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

class _Bubble extends StatelessWidget {
  final String displayText;
  final bool isUser;
  final bool showRaw;
  final VoidCallback onToggleRaw;

  const _Bubble({
    required this.displayText,
    required this.isUser,
    required this.showRaw,
    required this.onToggleRaw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            // leave room for toggle button on AI messages
            padding: EdgeInsets.only(right: isUser ? 0 : 22),
            child: SelectableText(
              displayText,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize:   15,
                height:     1.45,
                color:      isUser ? AppColors.userBubbleText : AppColors.aiBubbleText,
              ),
            ),
          ),

          // Raw/formatted toggle for AI messages
          if (!isUser)
            Positioned(
              top:   0,
              right: 0,
              child: GestureDetector(
                onTap: onToggleRaw,
                child: Tooltip(
                  message: showRaw ? 'Show formatted' : 'Show raw',
                  child: Icon(
                    showRaw ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size:  16,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final String path;
  const _ImageAttachment({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:      const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
      decoration:  BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 80,
            color:  AppColors.surfaceElevated,
            child: const Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}