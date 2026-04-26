import 'package:flutter/material.dart';

class AppColors {
  // ── Base Surfaces ──────────────────────────────────────────────────────────
  static const Color background       = Color(0xFF0A0A0F); // near-black canvas
  static const Color surface          = Color(0xFF13131A); // card/sheet surface
  static const Color surfaceElevated  = Color(0xFF1C1C26); // raised elements
  static const Color surfaceBorder    = Color(0xFF2A2A38); // subtle dividers

  // ── Accent ─────────────────────────────────────────────────────────────────
  static const Color accent           = Color(0xFF4F8EF7); // electric blue
  static const Color accentDim        = Color(0xFF243656); // muted accent bg
  static const Color accentGlow       = Color(0x334F8EF7); // glow / ring

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary      = Color(0xFFF0F0F5); // near-white
  static const Color textSecondary    = Color(0xFF8888A0); // muted label
  static const Color textDisabled     = Color(0xFF3D3D52); // placeholder

  // ── State Colors ───────────────────────────────────────────────────────────
  static const Color sentinel         = Color(0xFF9B6DFF); // purple — wake word active
  static const Color sentinelDim      = Color(0xFF2A1F45);
  static const Color listening        = Color(0xFFEF5350); // red — STT active
  static const Color listeningDim     = Color(0xFF3D1A1A);
  static const Color processing       = Color(0xFFFF9800); // amber — thinking
  static const Color processingDim    = Color(0xFF3D2800);
  static const Color speaking         = Color(0xFF4F8EF7); // blue — TTS
  static const Color speakingDim      = Color(0xFF162240);
  static const Color success          = Color(0xFF4CAF7A); // green
  static const Color successDim       = Color(0xFF0F2B1C);
  static const Color error            = Color(0xFFEF5350);
  static const Color errorDim         = Color(0xFF3D1A1A);

  // ── Chat Bubbles ───────────────────────────────────────────────────────────
  static const Color userBubble       = Color(0xFF243656); // dark-blue user
  static const Color userBubbleText   = Color(0xFFE8F0FF);
  static const Color aiBubble         = Color(0xFF1C1C26); // surface AI
  static const Color aiBubbleText     = Color(0xFFDDDDE8);

  // ── Legacy aliases (keeps existing code compiling) ─────────────────────────
  static const Color primary          = accent;
  static const Color primaryDark      = Color(0xFF2563C7);
  static const Color primaryLight     = accentDim;
  static const Color secondary        = sentinel;
  static const Color secondaryDark    = Color(0xFF6B3FCC);
  static const Color textPrimaryDark  = textPrimary;
  static const Color textSecondaryDark= textSecondary;
  static const Color userMessageBg    = userBubble;
  static const Color assistantMessageBg = aiBubble;
  static const Color messageText      = userBubbleText;
  static const Color assistantMessageText = aiBubbleText;
}