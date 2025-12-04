import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  TextToSpeechService() {
    _initTts();
  }

  void _initTts() {
    _tts.setStartHandler(() {
      print("TTS started");
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      print("TTS completed");
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      print("TTS error: $msg");
      _isSpeaking = false;
    });

    // Configure TTS settings
    _tts.setLanguage("en-US");
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    print('Speaking: $text');
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  bool get isSpeaking => _isSpeaking;
}
