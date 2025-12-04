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

  // Flag to track if the user manually stopped the session
  bool _isManualStop = false;

  VoiceCubit(
      this._speechService,
      this._ttsService,
      this._generateResponseUseCase,
      ) : super(VoiceInitial());

  Future<void> initializeServices() async {
    print('VoiceCubit: Initializing services...');
    emit(VoiceInitializing(_chatHistory));

    try {
      bool gemmaInitialized = await _generateResponseUseCase.repository.initializeModel();
      if (!gemmaInitialized) {
        emit(VoiceError('Failed to initialize AI model', _chatHistory));
        return;
      }

      bool speechAvailable = await _speechService.init();
      if (speechAvailable) {
        emit(SpeechReady(_chatHistory));
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
    // Reset manual stop flag
    _isManualStop = false;

    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    print('VoiceCubit: Starting listening...');
    _lastRecognizedText = '';
    emit(VoiceListening("", _chatHistory));

    _resetStateTimer?.cancel();

    await _speechService.startListening(
      onResult: (words) {
        _lastRecognizedText = words;
        emit(VoiceListening(words, _chatHistory));
      },
      onSessionComplete: () {
        if (!_isManualStop) {
          _handleListeningComplete();
        }
      },
    );
  }

  Future<void> stopListening() async {
    print('VoiceCubit: Manually stopping listening...');
    _isManualStop = true; // Set flag to prevent auto-restart
    _resetStateTimer?.cancel(); // Cancel any pending restarts

    await _speechService.stopListening();
    await _ttsService.stop();

    // Go directly to idle, do NOT process incomplete speech or restart
    emit(VoiceIdle(_chatHistory));
  }

  void _handleListeningComplete() async {
    if (_isManualStop) return;

    if (_lastRecognizedText.trim().isEmpty) {
      print('No speech detected (Silence/Error). Restarting loop...');
      emit(VoiceIdle(_chatHistory));

      _resetStateTimer?.cancel();
      _resetStateTimer = Timer(resetTimeout, () async {
        if (!isClosed && !_isManualStop) await startListening();
      });
      return;
    }

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _lastRecognizedText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    emit(VoiceProcessing(_lastRecognizedText, _chatHistory));

    try {
      await _generateStreamingResponse(_lastRecognizedText);
    } catch (e) {
      print('VoiceCubit: Error generating response: $e');
      String errorResponse = "I'm sorry, I encountered an error. Please try again.";

      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      emit(VoiceResponseReady(_lastRecognizedText, errorResponse, _chatHistory));

      await _ttsService.speak(errorResponse);
      await _ttsService.waitForCompletion();

      if (!_isManualStop) await startListening();
    }
  }

  Future<void> _generateStreamingResponse(String inputText) async {
    String fullRawResponse = '';
    String sentenceBuffer = '';

    // Create a temporary ID for the streaming message
    final streamMessageId = 'stream_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await for (String token in _generateResponseUseCase.callStreaming(inputText)) {
        if (_isManualStop) break; // Stop generating if user stopped

        fullRawResponse += token;
        sentenceBuffer += token;

        // --- SIMULTANEOUS TTS ---
        if (RegExp(r'[.?!:]').hasMatch(token) || RegExp(r'[.?!:]\s$').hasMatch(sentenceBuffer)) {
          if (sentenceBuffer.trim().length > 1) {
            final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
            _ttsService.speak(cleanSentence);
            sentenceBuffer = '';
          }
        }

        // --- SIMULTANEOUS UI UPDATE ---
        // Create a temporary message with the current incomplete text
        final streamingMessage = VoiceChatMessage(
          id: streamMessageId,
          text: fullRawResponse, // Markdown widget will render this
          rawContent: fullRawResponse,
          isUser: false,
          timestamp: DateTime.now(),
        );

        // Emit state with history + the streaming message appended
        emit(VoiceStreamingResponse(
            inputText,
            fullRawResponse,
            false,
            [..._chatHistory, streamingMessage] // Append explicitly for UI
        ));
      }

      if (_isManualStop) return;

      if (sentenceBuffer.trim().isNotEmpty) {
        final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
        _ttsService.speak(cleanSentence);
      }

      if (fullRawResponse.trim().isEmpty) {
        String fallback = "I didn't quite catch that.";
        fullRawResponse = fallback;
        _ttsService.speak(fallback);
      }

      // Finalize: Add the REAL final message to history
      final formattedResponse = TextFormatterService().formatAIResponse(fullRawResponse);
      final finalMessage = VoiceChatMessage(
        id: streamMessageId,
        text: formattedResponse,
        rawContent: fullRawResponse,
        formattedContent: formattedResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      _chatHistory.add(finalMessage);

      emit(VoiceResponseReady(inputText, formattedResponse, _chatHistory));
      emit(VoiceSpeaking(formattedResponse, _chatHistory));

      // Wait for audio
      await _ttsService.waitForCompletion();

      // Restart Loop
      if (!_isManualStop) {
        _resetStateTimer?.cancel();
        _resetStateTimer = Timer(resetTimeout, () async {
          if (!isClosed && !_isManualStop) await startListening();
        });
      }

    } catch (e) {
      print('Error in streaming response: $e');
      rethrow;
    }
  }

  Future<void> stopSpeaking() async {
    _isManualStop = true; // Treat stop speaking as manual stop
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
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _speechService.stopListening();
    await _ttsService.stop();
    await _generateResponseUseCase.repository.disposeModel();
    super.close();
  }
}