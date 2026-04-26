import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../logic/voice_cubit.dart';

/// Displays the current voice pipeline state as a compact pill badge.
/// Extracted from _VoiceChatBody so it can be reused and tested in isolation.
class VoiceStatusBadge extends StatelessWidget {
  final VoiceState state;
  final String activeWakeWord;
  final bool dark; // true when shown over camera feed

  const VoiceStatusBadge({
    Key? key,
    required this.state,
    required this.activeWakeWord,
    this.dark = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final info = _resolve(state, activeWakeWord);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(info.label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: dark
              ? info.color.withValues(alpha: 0.18)
              : info.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: info.color.withValues(alpha: dark ? 0.5 : 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing dot
            _PulseDot(color: info.color, animate: info.pulse),
            const SizedBox(width: 8),
            Text(
              info.label,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      dark ? Colors.white : info.color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusInfo _resolve(VoiceState state, String wakeWord) {
    final word = wakeWord.isNotEmpty
        ? '"${wakeWord[0].toUpperCase()}${wakeWord.substring(1)}"'
        : '"Hey"';

    if (state is VoiceInitializing) {
      return _StatusInfo(state.message, AppColors.processing, pulse: true);
    } else if (state is VoiceWaitingForWakeWord) {
      return _StatusInfo('Say $word', AppColors.sentinel, pulse: true);
    } else if (state is VoiceListening) {
      return _StatusInfo('Listening...', AppColors.listening, pulse: true);
    } else if (state is VoiceProcessing) {
      return _StatusInfo('Thinking...', AppColors.processing, pulse: true);
    } else if (state is VoiceStreamingResponse) {
      return _StatusInfo('Responding...', AppColors.speaking, pulse: true);
    } else if (state is VoiceSpeaking) {
      return _StatusInfo('Speaking...', AppColors.speaking, pulse: true);
    } else if (state is SpeechReady) {
      return _StatusInfo('Ready', AppColors.success, pulse: false);
    } else if (state is VoiceIdle) {
      return _StatusInfo('Paused', AppColors.textSecondary, pulse: false);
    } else if (state is SpeechUnavailable) {
      return _StatusInfo('Microphone unavailable', AppColors.error, pulse: false);
    } else if (state is VoiceError) {
      return _StatusInfo((state as VoiceError).errorMessage, AppColors.error, pulse: false);
    }
    return _StatusInfo('Initializing...', AppColors.textSecondary, pulse: true);
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final bool pulse;
  const _StatusInfo(this.label, this.color, {required this.pulse});
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulseDot({required this.color, required this.animate});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);

    if (old.animate != widget.animate) {
      if (widget.animate) {
        _c.repeat(reverse: true);
      } else {
        _c.stop();
        _c.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: widget.animate ? 0.4 + _c.value * 0.6 : 1.0),
        ),
      ),
    );
  }
}