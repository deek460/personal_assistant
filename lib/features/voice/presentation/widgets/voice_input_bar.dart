import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../logic/voice_cubit.dart';

/// The bottom input toolbar on the voice chat screen.
/// Contains: live-vision toggle, camera, gallery, text field, send.
/// Extracted so VoiceChatScreen stays readable.
class VoiceInputBar extends StatefulWidget {
  final VoiceState state;
  final bool isFullScreen;
  final VoidCallback onToggleLiveVision;
  final ValueChanged<String> onSendText;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onClearImage;

  const VoiceInputBar({
    Key? key,
    required this.state,
    required this.isFullScreen,
    required this.onToggleLiveVision,
    required this.onSendText,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onClearImage,
  }) : super(key: key);

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    widget.onSendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.isFullScreen;
    final liveOn = widget.state.isLiveVisionEnabled;

    return Container(
      decoration: BoxDecoration(
        color: fs ? Colors.black.withValues(alpha: 0.6) : AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pending image preview ──────────────────────────────────────
            if (widget.state.pendingImagePath != null)
              _PendingImagePreview(
                path:    widget.state.pendingImagePath!,
                onClear: widget.onClearImage,
              ),

            // ── Input row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Live vision toggle
                  _BarIconButton(
                    icon:     liveOn ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color:    liveOn ? AppColors.success : AppColors.textSecondary,
                    tooltip:  liveOn ? 'Disable live vision' : 'Enable live vision',
                    onTap:    widget.onToggleLiveVision,
                    fullScreen: fs,
                  ),

                  // Camera
                  _BarIconButton(
                    icon:     Icons.camera_alt_rounded,
                    color:    AppColors.textSecondary,
                    tooltip:  'Take photo',
                    onTap:    widget.onPickCamera,
                    fullScreen: fs,
                  ),

                  // Gallery
                  _BarIconButton(
                    icon:     Icons.photo_library_rounded,
                    color:    AppColors.textSecondary,
                    tooltip:  'Pick from gallery',
                    onTap:    widget.onPickGallery,
                    fullScreen: fs,
                  ),

                  const SizedBox(width: 4),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color:    fs ? Colors.white : AppColors.textPrimary,
                        fontSize: 15,
                        fontFamily: 'DM Sans',
                      ),
                      decoration: InputDecoration(
                        hintText:  'Type a message...',
                        hintStyle: TextStyle(
                          color: fs ? Colors.white38 : AppColors.textDisabled,
                          fontSize: 15,
                        ),
                        filled:    true,
                        fillColor: fs
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: fs ? Colors.white12 : AppColors.surfaceBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasText ? AppColors.accent : AppColors.surfaceElevated,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _hasText ? _send : null,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size:  20,
                          color: _hasText ? Colors.white : AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool fullScreen;

  const _BarIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.fullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: fullScreen ? Colors.white60 : color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _PendingImagePreview extends StatelessWidget {
  final String path;
  final VoidCallback onClear;
  const _PendingImagePreview({required this.path, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  width: 56, height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56, height: 56,
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
                  ),
                ),
              ),
              Positioned(
                top: -8, right: -8,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            'Image attached',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}