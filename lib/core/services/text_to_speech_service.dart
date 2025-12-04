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
    // We handle the queue manually, so we turn OFF the internal await for the public method
    // But we use it internally to ensure sequential playback.
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
}