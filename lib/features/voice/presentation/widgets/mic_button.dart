import 'package:flutter/material.dart';

enum MicButtonState { idle, listening, processing }

class MicButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (state) {
      case MicButtonState.listening:
        icon = Icons.mic;
        color = Colors.red;
        break;
      case MicButtonState.processing:
        icon = Icons.sync; // Or consider AnimatedIcon or CircularProgressIndicator overlay
        color = Colors.orange;
        break;
      case MicButtonState.idle:
      default:
        icon = Icons.mic_none;
        color = Colors.blueGrey;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(38),
          border: Border.all(color: color, width: 4),
        ),
        padding: const EdgeInsets.all(24),
        child: Icon(
          icon,
          color: color,
          size: 64,
        ),
      ),
    );
  }
}
