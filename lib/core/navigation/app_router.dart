import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/chat/presentation/pages/chat_screen.dart';
import '../../features/voice/presentation/pages/voice_chat_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String chat = '/chat';
  static const String voiceChat = '/voice_chat'; // Add this line

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: chat,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: voiceChat, // Add this route
        builder: (context, state) => const VoiceChatScreen(),
      ),
    ],
  );
}
