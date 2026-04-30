import 'dart:async';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  final Queue<String> _sentenceQueue = Queue<String>();
  bool _isSpeaking = false;
  Completer<void>? _queueCompleter;

  TextToSpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // On Android, we need to wait for the engine to bind
      await _tts.awaitSpeakCompletion(true);

      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      // REDUCED SPEED: Changed from 0.5 to 0.4 for better clarity/pauses
      await _tts.setSpeechRate(0.35);

      _tts.setStartHandler(() {
        print("TTS: Started speaking utterance");
      });

      _tts.setCompletionHandler(() {
        print("TTS: Completed utterance");
      });

      _tts.setErrorHandler((msg) {
        print("TTS error: $msg");
        _isSpeaking = false;
        _clearQueue();
      });
    } catch (e) {
      print("TTS Initialization Error: $e");
    }
  }

  /// Adds text to the queue and starts processing if idle.
  /// Returns a Future that completes when THIS specific text AND all previous texts finish.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    _sentenceQueue.add(text);

    if (!_isSpeaking) {
      _processQueue();
    }

    // If a completer exists, return its future, otherwise create one
    _queueCompleter ??= Completer<void>();
    return _queueCompleter!.future;
  }

  Future<void> _processQueue() async {
    if (_sentenceQueue.isEmpty) {
      _isSpeaking = false;
      // Notify anyone waiting that the entire queue is done
      if (_queueCompleter != null && !_queueCompleter!.isCompleted) {
        _queueCompleter!.complete();
        _queueCompleter = null;
      }
      return;
    }

    _isSpeaking = true;
    String nextSentence = _sentenceQueue.removeFirst();

    try {
      print('TTS processing: "$nextSentence"');
      // Because awaitSpeakCompletion is true, this awaits until audio finishes
      await _tts.speak(nextSentence);
    } catch (e) {
      print("TTS processing error: $e");
    } finally {
      // Recursive call to process next item
      _processQueue();
    }
  }

  Future<void> stop() async {
    _clearQueue();
    await _tts.stop();
    _isSpeaking = false;
  }

  void _clearQueue() {
    _sentenceQueue.clear();
    if (_queueCompleter != null && !_queueCompleter!.isCompleted) {
      _queueCompleter!.complete(); // Release any waiters
      _queueCompleter = null;
    }
  }

  bool get isSpeaking => _isSpeaking;

  /// Helper to wait for the current queue to drain completely
  Future<void> waitForCompletion() async {
    if (_queueCompleter != null) {
      await _queueCompleter!.future;
    }
  }

  // --- New Voice Management Methods ---

  Future<List<dynamic>> getAvailableVoices() async {
    try {
      // Retry logic: TTS engines sometimes take a moment to initialize on Android
      dynamic rawVoices;
      for (int i = 0; i < 3; i++) {
        rawVoices = await _tts.getVoices;
        if (rawVoices != null && (rawVoices as List).isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (rawVoices == null || rawVoices is! List) {
        print("TTS: getVoices returned null or not a list");
        return [];
      }

      print("TTS: Raw voices count: ${rawVoices.length}");

      final filtered = rawVoices.where((voice) {
        if (voice is Map) {
          final localeVal = voice['locale'] ?? voice['language'];
          if (localeVal == null) return false;

          final locale = localeVal.toString().toLowerCase();

          // 1. Region Filter (Keep relevant languages)
          // We restrict to English and Indian variants to avoid listing every world language
          bool isUS = locale.contains('en-us') || locale.contains('en_us');
          bool isUK = locale.contains('en-gb') || locale.contains('en_gb');
          bool isIndia = locale.contains('en-in') || locale.contains('en_in'); // Covers en-IN, hi-IN, bn-IN, etc.
          bool isHindi = locale.contains('local') || locale.contains('language');

          if (!isUS && !isUK && !isIndia) return false;

          // 2. OFFLINE FILTER (Critical)
          // Check 'isNetworkConnectionRequired'. If true, it means the voice needs internet.
          // We want ONLY voices where this is FALSE or NULL (assumed local).
          if (voice.containsKey('isNetworkConnectionRequired')) {
            if (voice['isNetworkConnectionRequired'] == true) {
              return false; // Exclude network voices
            }
          }

          // Additional check: 'networkRequired' key (varies by engine version)
          if (voice.containsKey('networkRequired')) {
            if (voice['networkRequired'] == true) {
              return false;
            }
          }

          // If we passed checks, it's likely an offline voice
          return true;
        }
        return false;
      }).toList();

      print("TTS: Offline-capable filtered voices count: ${filtered.length}");

      // Sort: India first, then US/UK
      filtered.sort((a, b) {
        final localeA = (a['locale'] ?? '').toString();
        final localeB = (b['locale'] ?? '').toString();
        return localeA.compareTo(localeB);
      });

      return filtered;

    } catch (e) {
      print("TTS Error fetching voices: $e");
      return [];
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    try {
      print("TTS: Setting voice to $voice");
      await _tts.setVoice(voice);
    } catch (e) {
      print("TTS Error setting voice: $e");
    }
  }
}