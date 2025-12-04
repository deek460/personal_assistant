import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  // Callback to handle errors dynamically
  Function(SpeechRecognitionError)? _onErrorCallback;
  // Callback to handle status changes
  Function(String)? _onStatusCallback;

  Future<bool> init() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('Microphone permission denied');
      return false;
    }

    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        _onStatusCallback?.call(status);
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        _onErrorCallback?.call(errorNotification);
      },
      debugLogging: true,
    );

    print('Speech recognition available: $_isAvailable');
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    // Renamed for clarity, this is called when session ends (silence/done/error)
    required Function() onSessionComplete,
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return;
    }

    // Hook up the error callback for this session
    _onErrorCallback = (error) {
      // If we get a "no match" or other permanent error, treat session as done
      if (error.permanent || error.errorMsg == 'error_no_match') {
        print('Permanent speech error detected. Ending session.');
        onSessionComplete();
      }
    };

    // Hook up status callback to detect 'done' or 'notListening'
    _onStatusCallback = (status) {
      if (status == 'done' || status == 'notListening') {
        // SpeechToText often sends 'done' after final result.
      }
    };

    print('Starting to listen...');
    await _speech.listen(
      onResult: (result) {
        print('Speech result: "${result.recognizedWords}" (confidence: ${result.confidence})');
        onResult(result.recognizedWords);

        if (result.finalResult) {
          print('Final result received, stopping...');
          onSessionComplete();
        }
      },
      listenFor: const Duration(seconds: 60), // Increased to 60s
      pauseFor: const Duration(seconds: 5),   // Increased pause tolerance
      localeId: 'en_US',
      cancelOnError: true,
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