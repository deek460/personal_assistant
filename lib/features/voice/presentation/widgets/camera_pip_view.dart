import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A floating picture-in-picture camera preview.
/// Shown in the top-right corner when live vision is on but not in fullscreen.
class CameraPipView extends StatelessWidget {
  final CameraController controller;
  final VoidCallback onExpand;

  const CameraPipView({
    Key? key,
    required this.controller,
    required this.onExpand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withValues(alpha: 0.5),
            blurRadius:  16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),

            // Expand button
            Positioned(
              bottom: 6,
              right: 6,
              child: GestureDetector(
                onTap: onExpand,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),

            // Live indicator
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.white),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen camera overlay with an exit button.
class CameraFullScreenOverlay extends StatelessWidget {
  final CameraController controller;
  final VoidCallback onCollapse;

  const CameraFullScreenOverlay({
    Key? key,
    required this.controller,
    required this.onCollapse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Center(child: CameraPreview(controller)),

        // Exit fullscreen
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: onCollapse,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}