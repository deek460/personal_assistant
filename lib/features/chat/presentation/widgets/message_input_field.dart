import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class MessageInputField extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;

  const MessageInputField({
    super.key,
    required this.onSendMessage,
    this.isLoading = false,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty && !widget.isLoading;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    HapticFeedback.lightImpact();
    final msg = _controller.text.trim();
    _controller.clear();
    widget.onSendMessage(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller:      _controller,
                enabled:         !widget.isLoading,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize:   15,
                  color:      AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Message...',
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),

            const SizedBox(width: 10),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _canSend ? AppColors.accent : AppColors.surfaceElevated,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: _canSend ? _send : null,
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth:  2,
                        valueColor:   AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : Icon(
                      Icons.arrow_upward_rounded,
                      size:  20,
                      color: _canSend ? Colors.white : AppColors.textDisabled,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}