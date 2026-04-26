import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';

enum MicButtonState { idle, sentinel, listening, processing, speaking }

class MicButton extends StatefulWidget {
  final MicButtonState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MicButton({
    Key? key,
    required this.state,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _updatePulse();
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updatePulse();
  }

  void _updatePulse() {
    if (widget.state == MicButtonState.sentinel ||
        widget.state == MicButtonState.listening) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _StateStyle get _style {
    switch (widget.state) {
      case MicButtonState.sentinel:
        return _StateStyle(
          color:     AppColors.sentinel,
          dimColor:  AppColors.sentinelDim,
          icon:      Icons.hearing,
          label:     'Listening for wake word',
        );
      case MicButtonState.listening:
        return _StateStyle(
          color:     AppColors.listening,
          dimColor:  AppColors.listeningDim,
          icon:      Icons.mic,
          label:     'Listening...',
        );
      case MicButtonState.processing:
        return _StateStyle(
          color:     AppColors.processing,
          dimColor:  AppColors.processingDim,
          icon:      Icons.psychology,
          label:     'Thinking...',
        );
      case MicButtonState.speaking:
        return _StateStyle(
          color:     AppColors.speaking,
          dimColor:  AppColors.speakingDim,
          icon:      Icons.volume_up_rounded,
          label:     'Speaking...',
        );
      case MicButtonState.idle:
        return _StateStyle(
          color:     AppColors.textSecondary,
          dimColor:  AppColors.surfaceElevated,
          icon:      Icons.mic_none_rounded,
          label:     'Tap to speak',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Outer pulse ring ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final t = _pulseController.value;
                final scale = 1.0 + t * 0.5;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s.color.withValues(alpha: opacity * 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Inner pulse ring ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final t = (_pulseController.value + 0.3) % 1.0;
                final scale = 1.0 + t * 0.3;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s.color.withValues(alpha: opacity * 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Button body ──────────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape:   BoxShape.circle,
                color:   s.dimColor,
                border:  Border.all(color: s.color.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color:       s.color.withValues(alpha: 0.25),
                    blurRadius:  24,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: widget.state == MicButtonState.processing
                  ? Padding(
                padding: const EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(s.color),
                ),
              )
                  : Icon(s.icon, color: s.color, size: 32)
                  .animate(key: ValueKey(widget.state))
                  .fadeIn(duration: 200.ms)
                  .scale(begin: const Offset(0.7, 0.7), duration: 200.ms, curve: Curves.easeOutBack),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateStyle {
  final Color color;
  final Color dimColor;
  final IconData icon;
  final String label;
  const _StateStyle({required this.color, required this.dimColor, required this.icon, required this.label});
}