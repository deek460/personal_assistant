import 'dart:async';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:flutter_wake_word/instance_config.dart';
import '../../../../core/constants/app_constants.dart';

class WakeWordService {
  final FlutterWakeWord _wakeWordPlugin = FlutterWakeWord();

  bool _isListening = false;
  bool _isTriggering = false;
  String _activeWakeWord = '';

  // // 🔴 CACHE: Prevents the "Already Initialized" native crash
  // final Set<String> _registeredWords = {};
  // 🔴 CACHE: Stores config hash alongside word to detect config changes
  final Map<String, String> _registeredWords = {}; // instanceId -> configHash

  String _makeConfigHash(double threshold, int bufferCnt) =>
      '${threshold}_$bufferCnt';

  // ✅ Call once before startListening is ever used
  Future<void> initialize() async {
    try {
      await _wakeWordPlugin.useModel.setKeywordDetectionLicense(
        AppConstants.wakeWordLicenseKey,
      );
      print("✅ WakeWordService: License key set.");
    } catch (e) {
      print("❌ WakeWordService: License init failed: $e");
    }
  }

  Future<bool> startListening({
    required String wakeWord,
    required Function() onDetect,
  }) async {
    if (_isListening) return true;
    _isTriggering = false;

    final instanceId = wakeWord.toLowerCase();
    final modelFileName = '$instanceId.onnx';
    const double threshold = 0.8000;
    const int bufferCnt = 1;
    final currentConfigHash = _makeConfigHash(threshold, bufferCnt);

    try {
      final existingConfigHash = _registeredWords[instanceId];

      if (existingConfigHash != null && existingConfigHash != currentConfigHash) {
        // ✅ Config changed — remove the stale instance so it gets re-added fresh
        print("🔄 WakeWordService: Config changed for '$wakeWord', reinitializing...");
        try {
          await _wakeWordPlugin.useModel.removeInstance(instanceId);
        } catch (e) {
          print("⚠️ WakeWordService: Could not remove old instance: $e");
        }
        _registeredWords.remove(instanceId);
      }

      if (!_registeredWords.containsKey(instanceId)) {
        print("🎧 WakeWordService: Initializing NEW instance for '$wakeWord'...");
        await _wakeWordPlugin.useModel.addInstance(
          InstanceConfig(
            id: instanceId,
            modelName: modelFileName,
            threshold: threshold,
            bufferCnt: bufferCnt,
            sticky: false,
          ),
              (Map<String, dynamic> event) {
            if (_isTriggering) return;
            final detectedPhrase = event['phrase'] as String? ?? instanceId;
            if (detectedPhrase.toLowerCase().trim() != _activeWakeWord.toLowerCase().trim()) return;
            print("🚨 WakeWordService: WAKE WORD DETECTED! ($detectedPhrase)");
            _isTriggering = true;
            onDetect();
          },
        );
        _registeredWords[instanceId] = currentConfigHash; // ✅ Store with config hash
      }

      _activeWakeWord = instanceId;

      try {
        await _wakeWordPlugin.startKeywordDetection(threshold);
      } catch (e) {
        print("⚠️ Native Engine Note: Already listening. ($e)");
      }

      _isListening = true;
      print("✅ WakeWordService: Sentinel active for '$_activeWakeWord'...");
      return true;
    } catch (e) {
      print("❌ WakeWordService: Failed to start listening: $e");
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    _isTriggering = false;
    try {
      await _wakeWordPlugin.stopKeywordDetection();
      print("🛑 WakeWordService: Sentinel stopped. Microphone released.");
    } catch (e) {
      print("❌ WakeWordService Error stopping: $e");
    }
  }

  bool get isListening => _isListening;
}