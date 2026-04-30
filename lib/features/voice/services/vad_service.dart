import 'dart:async';
import 'package:vad/vad.dart';

class VadService {
  static const double _threshold = 0.5;
  static const int _speechFramesRequired = 3;

  final VadHandler _vad = VadHandler.create(isDebug: false);

  bool _isListening = false;
  bool _isTriggering = false;
  int _speechFrameCount = 0;

  StreamSubscription? _speechStartSub;
  StreamSubscription? _frameSub;
  StreamSubscription? _errorSub;

  /// Call once at app start — vad package handles model loading internally.
  Future<void> initialize() async {
    try {
      _errorSub = _vad.onError.listen((error) {
        print('❌ VadService: $error');
      });
      print('✅ VadService: Initialized.');
    } catch (e) {
      print('❌ VadService: Failed to initialize: $e');
    }
  }

  Future<bool> startListening({required Function() onDetect}) async {
    if (_isListening) return true;

    _isTriggering = false;
    _speechFrameCount = 0;

    // Listen frame-by-frame so we can replicate your
    // "N consecutive speech frames" logic before firing onDetect.
    _frameSub = _vad.onFrameProcessed.listen((frame) {
      if (_isTriggering) return;

      final prob = frame.isSpeech; // correct field name

      if (prob >= _threshold) {
        _speechFrameCount++;
        if (_speechFrameCount >= _speechFramesRequired) {
          print('🗣️ VadService: Speech detected (prob=$prob). Firing onDetect.');
          _isTriggering = true;
          _speechFrameCount = 0;
          onDetect();
        }
      } else {
        _speechFrameCount = 0;
      }
    });

    try {
      await _vad.startListening(
        model: 'v4',                              // Silero VAD v4
        positiveSpeechThreshold: _threshold,
        negativeSpeechThreshold: _threshold - 0.15,
        minSpeechFrames: _speechFramesRequired,
        preSpeechPadFrames: 10,
        redemptionFrames: 8,
      );

      _isListening = true;
      print('✅ VadService: Listening for speech...');
      return true;
    } catch (e) {
      print('❌ VadService: Failed to start listening: $e');
      await _frameSub?.cancel();
      _frameSub = null;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    _isTriggering = false;
    _speechFrameCount = 0;

    await _frameSub?.cancel();
    _frameSub = null;

    await _vad.stopListening();
    print('🛑 VadService: Stopped. Microphone released.');
  }

  /// Reset the triggering flag so VAD can fire onDetect again
  /// after a speech session completes. Call this after your STT finishes.
  void resetTrigger() {
    _isTriggering = false;
    _speechFrameCount = 0;
  }

  void dispose() {
    stopListening();
    _speechStartSub?.cancel();
    _errorSub?.cancel();
    _vad.dispose();
  }

  bool get isListening => _isListening;
}