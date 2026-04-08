import 'dart:convert';
import 'package:vosk_flutter/vosk_flutter.dart';

class WakeWordService {
  static const String _modelAsset = 'assets/models/vosk-model-small-en-us-0.15.zip';

  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isListening = false;
  bool _isTriggering = false; // Prevents double-firing during handoff

  Future<bool> init() async {
    try {
      print("🎧 WakeWordService: Extracting and loading Vosk model...");
      final modelPath = await ModelLoader().loadFromAssets(_modelAsset);
      _model = await _vosk.createModel(modelPath);
      print("✅ WakeWordService: Vosk model loaded successfully.");
      return true;
    } catch (e) {
      print("❌ WakeWordService Init Error: $e");
      return false;
    }
  }

  /// We recreate the recognizer when starting to ensure the grammar strictly
  /// matches the currently selected wake word (e.g., if the user changes it in settings).
  Future<void> startListening({
    required String wakeWord,
    required Function() onDetect
  }) async {
    if (_model == null) return;
    if (_isListening) await stopListening();

    _isTriggering = false;

    try {
      // 1. Create a STRICT grammar constraint.
      // Vosk will throw away all audio unless it mathematically matches the wake word.
      // FIX: Pass the List directly instead of jsonEncode
      final grammar = [wakeWord.toLowerCase(), "[unk]"];

      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: grammar,
      );

      // 2. Bind the microphone to Vosk
      _speechService = await _vosk.initSpeechService(_recognizer!);

      // 3. Listen to partial results for ultra-fast (sub-second) detection
      _speechService!.onPartial().listen((event) {
        if (_isTriggering) return; // Ignore if we are already handing off

        final partialMap = jsonDecode(event);
        final partialText = (partialMap['partial'] as String).toLowerCase();

        if (partialText.contains(wakeWord.toLowerCase())) {
          print("🚨 WakeWordService: WAKE WORD DETECTED! ('$partialText')");
          _isTriggering = true;
          onDetect();
        }
      });

      await _speechService!.start();
      _isListening = true;
      print("🎧 WakeWordService: Sentinel active. Listening strictly for '$wakeWord'.");

    } catch (e) {
      print("❌ WakeWordService Error starting: $e");
    }
  }

  /// Completely releases the microphone so standard STT can use it
  Future<void> stopListening() async {
    if (!_isListening || _speechService == null) return;

    try {
      await _speechService!.stop();
      await _speechService!.dispose(); // CRITICAL: Frees the audio buffer
      _speechService = null;

      if (_recognizer != null) {
        _recognizer!.dispose();
        _recognizer = null;
      }

      _isListening = false;
      print("🛑 WakeWordService: Stopped. Microphone released.");
    } catch (e) {
      print("❌ WakeWordService Error stopping: $e");
    }
  }
}