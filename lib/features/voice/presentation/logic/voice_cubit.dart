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

  // Timer to reset state after speaking, but NOT to restart listening automatically
  Timer? _resetStateTimer;
  static const Duration resetTimeout = Duration(seconds: 2);

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
      } else {
        emit(SpeechUnavailable(_chatHistory));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory));
    }
  }

  Future<void> startListening() async {
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
      onSilenceTimeout: () {
        _handleListeningComplete();
      },
    );
  }

  Future<void> stopListening() async {
    print('VoiceCubit: Manually stopping listening...');
    await _speechService.stopListening();
    _handleListeningComplete();
  }

  void _handleListeningComplete() async {
    if (_lastRecognizedText.trim().isEmpty) {
      print('No speech detected, returning to idle');
      emit(VoiceIdle(_chatHistory));
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
      String errorResponse = "I'm sorry, I encountered an error while processing your request. Please try again.";

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

    await _ttsService.speak(ttsText);

    // After TTS completes, wait a moment and then go to Idle (Manual Mode)
    _resetStateTimer?.cancel();
    _resetStateTimer = Timer(resetTimeout, () async {
      print('VoiceCubit: TTS complete. Returning to Idle state.');
      emit(VoiceIdle(_chatHistory));
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isNotEmpty) {
      await _speakResponse(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory));
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
    // No wake word service to dispose
    super.close();
  }
}