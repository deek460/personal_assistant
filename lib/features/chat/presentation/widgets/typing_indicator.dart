import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  AppColors.surfaceElevated,
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size:  16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),

          // Dots bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:  AppColors.aiBubble,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(16),
                topRight:    Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft:  Radius.circular(4),
              ),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(controller: _controller, delay: 0.0),
                const SizedBox(width: 5),
                _Dot(controller: _controller, delay: 0.2),
                const SizedBox(width: 5),
                _Dot(controller: _controller, delay: 0.4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _Dot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t       = (controller.value - delay) % 1.0;
        final opacity = t < 0.5
            ? (t * 2).clamp(0.25, 1.0)
            : ((1.0 - t) * 2).clamp(0.25, 1.0);
        final scale   = 0.75 + opacity * 0.25;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}