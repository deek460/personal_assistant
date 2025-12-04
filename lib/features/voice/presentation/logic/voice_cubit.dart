import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../data/models/voice_chat_message.dart';
import '../../../gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../../../../core/services/text_formatter_service.dart';

abstract class VoiceState {
  final List<VoiceChatMessage> chatHistory;
  VoiceState(this.chatHistory);
}

class VoiceInitial extends VoiceState {
  VoiceInitial() : super([]);
}

class VoiceInitializing extends VoiceState {
  VoiceInitializing(List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class SpeechReady extends VoiceState {
  SpeechReady(List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class SpeechUnavailable extends VoiceState {
  SpeechUnavailable(List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceListening extends VoiceState {
  final String recognizedWords;
  VoiceListening(this.recognizedWords, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceProcessing extends VoiceState {
  final String inputText;
  VoiceProcessing(this.inputText, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceStreamingResponse extends VoiceState {
  final String inputText;
  final String partialResponse;
  final bool isComplete;
  VoiceStreamingResponse(this.inputText, this.partialResponse, this.isComplete, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceResponseReady extends VoiceState {
  final String inputText;
  final String responseText;
  VoiceResponseReady(this.inputText, this.responseText, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceSpeaking extends VoiceState {
  final String responseText;
  VoiceSpeaking(this.responseText, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceIdle extends VoiceState {
  VoiceIdle(List<VoiceChatMessage> chatHistory) : super(chatHistory);
}

class VoiceError extends VoiceState {
  final String errorMessage;
  VoiceError(this.errorMessage, List<VoiceChatMessage> chatHistory) : super(chatHistory);
}


class VoiceCubit extends Cubit<VoiceState> {
  final SpeechToTextService _speechService;
  final TextToSpeechService _ttsService;
  final GenerateResponseUseCase _generateResponseUseCase;

  String _lastRecognizedText = '';
  List<VoiceChatMessage> _chatHistory = [];

  // Timer to reset state after speaking or silence
  Timer? _resetStateTimer;
  static const Duration resetTimeout = Duration(milliseconds: 500);

  VoiceCubit(
      this._speechService,
      this._ttsService,
      this._generateResponseUseCase,
      ) : super(VoiceInitial());

  Future<void> initializeServices() async {
    print('VoiceCubit: Initializing services...');
    emit(VoiceInitializing(_chatHistory));

    try {
      // Initialize Gemma model
      bool gemmaInitialized = await _generateResponseUseCase.repository.initializeModel();
      if (!gemmaInitialized) {
        emit(VoiceError('Failed to initialize AI model', _chatHistory));
        return;
      }

      // Initialize speech recognition service
      bool speechAvailable = await _speechService.init();
      if (speechAvailable) {
        emit(SpeechReady(_chatHistory));
        // HANDS-FREE: Auto-start listening immediately once ready
        print('VoiceCubit: Services ready. Auto-starting listening...');
        await startListening();
      } else {
        emit(SpeechUnavailable(_chatHistory));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory));
    }
  }

  Future<void> startListening() async {
    // Safety check: Don't start listening if TTS is still active (double check)
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    print('VoiceCubit: Starting listening...');
    _lastRecognizedText = '';
    emit(VoiceListening("", _chatHistory));

    _resetStateTimer?.cancel();

    await _speechService.startListening(
      onResult: (words) {
        print('VoiceCubit: Recognized words: $words');
        _lastRecognizedText = words;
        emit(VoiceListening(words, _chatHistory));
      },
      // This now acts as "Session Complete" (valid OR invalid/silence)
      onSessionComplete: () {
        _handleListeningComplete();
      },
    );
  }

  Future<void> stopListening() async {
    print('VoiceCubit: Manually stopping listening...');
    await _speechService.stopListening();
    // When stopping manually, we might NOT want to auto-restart.
    // So we check if the state implies manual intervention?
    // Actually, stopListening implies we want to process what we have or just stop.
    _handleListeningComplete();
  }

  void _handleListeningComplete() async {
    // If silence/empty text
    if (_lastRecognizedText.trim().isEmpty) {
      print('No speech detected (Silence/Error). Restarting loop...');

      // Update UI to Idle briefly
      emit(VoiceIdle(_chatHistory));

      // Auto-restart loop
      _resetStateTimer?.cancel();
      _resetStateTimer = Timer(resetTimeout, () async {
        if (!isClosed) { // Safety check
          await startListening();
        }
      });
      return;
    }

    // Add user input to chat history
    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _lastRecognizedText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    print('VoiceCubit: Processing input with AI: $_lastRecognizedText');
    emit(VoiceProcessing(_lastRecognizedText, _chatHistory));

    try {
      // Generate AI response with streaming
      await _generateStreamingResponse(_lastRecognizedText);

    } catch (e) {
      print('VoiceCubit: Error generating response: $e');
      String errorResponse = "I'm sorry, I encountered an error. Please try again.";

      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorResponse,
        rawContent: errorResponse,
        formattedContent: errorResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      emit(VoiceResponseReady(_lastRecognizedText, errorResponse, _chatHistory));
      await _speakResponse(errorResponse);
    }
  }

  Future<void> _generateStreamingResponse(String inputText) async {
    String fullRawResponse = '';

    try {
      await for (String token in _generateResponseUseCase.callStreaming(inputText)) {
        fullRawResponse += token;
        emit(VoiceStreamingResponse(inputText, fullRawResponse, false, _chatHistory));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Handle empty response scenario
      if (fullRawResponse.trim().isEmpty) {
        print('VoiceCubit: Warning - Received empty response from model.');
        fullRawResponse = "I didn't quite catch that. Could you please rephrase?";
      }

      emit(VoiceStreamingResponse(inputText, fullRawResponse, true, _chatHistory));
      final formattedResponse = TextFormatterService().formatAIResponse(fullRawResponse);

      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: formattedResponse,
        rawContent: fullRawResponse,
        formattedContent: formattedResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      emit(VoiceResponseReady(inputText, formattedResponse, _chatHistory));
      await _speakResponse(formattedResponse);

    } catch (e) {
      print('Error in streaming response: $e');
      rethrow;
    }
  }

  Future<void> _speakResponse(String text) async {
    final ttsText = TextFormatterService().formatForTTS(text);

    print('VoiceCubit: Speaking response (formatted for TTS): $ttsText');
    emit(VoiceSpeaking(ttsText, _chatHistory));

    // Wait until speech audio is fully finished
    await _ttsService.speak(ttsText);

    // HANDS-FREE LOOP: Auto-restart listening
    _resetStateTimer?.cancel();
    _resetStateTimer = Timer(resetTimeout, () async {
      print('VoiceCubit: TTS complete. Auto-restarting listening for hands-free loop...');
      if (!isClosed) {
        await startListening();
      }
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isNotEmpty) {
      await _speakResponse(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    // If user manually stops speaking, they probably want to talk now
    emit(VoiceIdle(_chatHistory));
    // Optional: Auto-start listening here?
  }

  Future<void> restartListening() async {
    await startListening();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    emit(VoiceIdle(_chatHistory));
  }

  @override
  Future<void> close() async {
    await _generateResponseUseCase.repository.disposeModel();
    super.close();
  }
}