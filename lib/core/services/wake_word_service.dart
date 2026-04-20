import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:flutter_wake_word/instance_config.dart';
import 'package:flutter_wake_word/use_model.dart';

class WakeWordService {
  final FlutterWakeWord _wakeWordPlugin = FlutterWakeWord();

  // Access UseModel directly — this is how the official example works
  UseModel get useModel => _wakeWordPlugin.useModel;

  bool _isListening = false;
  bool _isTriggering = false;
  String _activeWakeWord = '';

  // License key — set to empty string if you don't have one
  static const String _license = 'MTc4Mjg1MzIwMDAwMA==-QYH+tF+Y9UvHypFSSYJNi/RwYHcabxWtw/Ir3Y5CoI8=';

  /// Starts wake word detection for a specific ONNX model file.
  ///
  /// [wakeWord] must match the bare filename of an asset placed in
  /// android/app/src/main/assets/ (e.g. "jarvis" → "jarvis.onnx").
  Future<bool> startListening({
    required String wakeWord,
    required Function() onDetect,
  }) async {
    if (_isListening) return true;

    _isTriggering = false;

    final instanceId = wakeWord.toLowerCase();
    final modelFileName = '$instanceId.onnx';

    try {
      print("🎧 WakeWordService: Initializing instance for '$wakeWord'...");

      // Step 1: set license (required even if empty)
        await useModel.setKeywordDetectionLicense(_license);

      // Step 2: register via MultiInstanceConfig (official pattern)
      final config = MultiInstanceConfig(
        id: instanceId,
        modelNames: [modelFileName],
        thresholds: [0.90],
        bufferCnts: [3],
        msBetweenCallback: [1000],
        sticky: false,
      );

      await useModel.addInstanceMulti(
        config,
            (Map<String, dynamic> event) {
          // Prevent double-firing while the app transitions to STT
          if (_isTriggering) return;

          final detectedPhrase = event['phrase'] as String? ?? instanceId;
          print("🚨 WakeWordService: WAKE WORD DETECTED! ($detectedPhrase)");
          _isTriggering = true;
          onDetect();
        },
      );

      // Step 3: start the audio loop
      await useModel.startListening();

      _activeWakeWord = instanceId;
      _isListening = true;

      print(
        "✅ WakeWordService: Sentinel active. Listening for '$_activeWakeWord'...",
      );
      return true;
    } on PlatformException catch (e) {
      final msg = e.code == 'LICENSE_NOT_VALID'
          ? 'Wake word license invalid or expired.'
          : 'Wake word failed to start: ${e.message ?? e.code}';
      print("❌ WakeWordService: $msg");
      return false;
    } catch (e) {
      print("❌ WakeWordService: Failed to start listening: $e");
      return false;
    }
  }

  /// Call this after onDetect fires to resume listening (mirrors official example).
  Future<void> resumeListening() async {
    if (_isListening) return;
    try {
      await useModel.startListening();
      _isListening = true;
      _isTriggering = false;
      print("🎧 WakeWordService: Resumed listening for '$_activeWakeWord'...");
    } catch (e) {
      print("❌ WakeWordService: Failed to resume: $e");
    }
  }

  /// Stops wake word detection and releases the microphone.
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await useModel.stopListening();

      _isListening = false;
      _isTriggering = false;
      _activeWakeWord = '';

      print("🛑 WakeWordService: Sentinel stopped. Microphone released.");
    } catch (e) {
      print("❌ WakeWordService Error stopping: $e");
    }
  }

  /// Pauses the audio loop without destroying the registered instance.
  /// Call resumeListening() to restart. Faster than a full stop/start cycle.
  Future<void> pauseListening() async {
    if (!_isListening) return;
    try {
      await useModel.stopListening();
      _isListening = false;
      _isTriggering = false;
      print("⏸️ WakeWordService: Paused (instance kept alive).");
    } catch (e) {
      print("❌ WakeWordService Error pausing: $e");
    }
  }

  /// Whether the service is currently listening.
  bool get isListening => _isListening;
  bool get isInitialized => _activeWakeWord.isNotEmpty;
}