import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> init() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    print('Microphone permission status: $status');

    if (status != PermissionStatus.granted) {
      print('Microphone permission denied');
      return false;
    }

    // Initialize speech recognition
    _isAvailable = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (errorNotification) => print('Speech error: $errorNotification'),
      debugLogging: true,
    );

    print('Speech recognition available: $_isAvailable');
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required Function() onSilenceTimeout, // New callback for silence timeout
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return;
    }

    print('Starting to listen...');
    await _speech.listen(
      onResult: (result) {
        print('Speech result: "${result.recognizedWords}" (confidence: ${result.confidence})');
        onResult(result.recognizedWords);

        // If final result, stop listening automatically
        if (result.finalResult) {
          print('Final result received, stopping...');
          onSilenceTimeout();
          }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      onSoundLevelChange: (level) {
        if (level > 0.1) {
          print('🎵 Sound level: ${level.toStringAsFixed(2)}');
        }
      },
      // Use the new SpeechListenOptions instead of deprecated parameters
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      print('Stopped listening');
    }
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isAvailable;
}
