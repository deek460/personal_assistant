import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/string_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeContent();
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Header ────────────────────────────────────────────────────
              _Header()
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: -0.1, duration: 500.ms, curve: Curves.easeOutCubic),

              const Spacer(),

              // ── Central mic CTA ───────────────────────────────────────────
              Center(
                child: _MicCta(
                  onTap: () => context.go(AppRouter.voiceChat),
                ).animate(delay: 150.ms)
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.9, 0.9), duration: 500.ms, curve: Curves.easeOutBack),
              ),

              const Spacer(),

              // ── Quick actions grid ────────────────────────────────────────
              _QuickActionsRow()
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          StringConstants.homeTitle,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Central mic CTA ───────────────────────────────────────────────────────────

class _MicCta extends StatefulWidget {
  final VoidCallback onTap;
  const _MicCta({required this.onTap});

  @override
  State<_MicCta> createState() => _MicCtaState();
}

class _MicCtaState extends State<_MicCta> with SingleTickerProviderStateMixin {
  late AnimationController _ring;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTapDown:   (_) => setState(() => _pressed = true),
          onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel: ()  => setState(() => _pressed = false),
          child: SizedBox(
            width:  180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer slow ring
                AnimatedBuilder(
                  animation: _ring,
                  builder: (_, __) {
                    final t = _ring.value;
                    return Transform.scale(
                      scale: 1.0 + t * 0.35,
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: (1.0 - t) * 0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Inner ring
                AnimatedBuilder(
                  animation: _ring,
                  builder: (_, __) {
                    final t = (_ring.value + 0.4) % 1.0;
                    return Transform.scale(
                      scale: 1.0 + t * 0.2,
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: (1.0 - t) * 0.15),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Button
                AnimatedScale(
                  scale:    _pressed ? 0.94 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentDim,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:       AppColors.accent.withValues(alpha: 0.2),
                          blurRadius:  40,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      color: AppColors.accent,
                      size:  48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Tap to talk',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon:    Icons.chat_bubble_outline_rounded,
            label:   'Chat',
            sub:     'Text mode',
            color:   AppColors.accent,
            onTap:   () => context.go(AppRouter.chat),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon:    Icons.tune_rounded,
            label:   'Settings',
            sub:     'Configure',
            color:   AppColors.sentinel,
            onTap:   () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open from voice screen')),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:  AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.sub,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}