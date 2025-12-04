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
      print('No speech detected (Silence/Error). Restarting loop...');
      emit(VoiceIdle(_chatHistory));

      _resetStateTimer?.cancel();
      _resetStateTimer = Timer(resetTimeout, () async {
        if (!isClosed) await startListening();
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

      // Update UI with error
      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: errorResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      emit(VoiceResponseReady(_lastRecognizedText, errorResponse, _chatHistory));

      // Speak error
      await _ttsService.speak(errorResponse);
      await _ttsService.waitForCompletion();

      // Restart loop
      await startListening();
    }
  }

  Future<void> _generateStreamingResponse(String inputText) async {
    String fullRawResponse = '';
    String sentenceBuffer = '';

    // UI placeholder for the streaming message
    // We add it to history once, then update it in place via state emissions
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // We don't add to _chatHistory list yet to avoid duplicates,
    // we will emit states with the growing text.

    try {
      await for (String token in _generateResponseUseCase.callStreaming(inputText)) {
        fullRawResponse += token;
        sentenceBuffer += token;

        // --- SIMULTANEOUS TTS LOGIC ---
        // Check for sentence delimiters (. ? ! :)
        // We look for a punctuation mark followed by a space or end of string
        if (RegExp(r'[.?!:]').hasMatch(token) || RegExp(r'[.?!:]\s$').hasMatch(sentenceBuffer)) {
          // Basic check: Ensure we have a reasonable length or it's just an initial "Okay."
          if (sentenceBuffer.trim().length > 1) {
            final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
            print("Queuing sentence for TTS: $cleanSentence");
            // Fire and forget - add to queue
            _ttsService.speak(cleanSentence);
            sentenceBuffer = ''; // Clear buffer
          }
        }

        // Update UI with FULL text so far
        // Note: formattedContent will be handled by the UI using Markdown widget
        emit(VoiceStreamingResponse(inputText, fullRawResponse, false, _chatHistory));
      }

      // Process any remaining text in buffer after stream ends
      if (sentenceBuffer.trim().isNotEmpty) {
        final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
        _ttsService.speak(cleanSentence);
      }

      // Handle empty response
      if (fullRawResponse.trim().isEmpty) {
        String fallback = "I didn't quite catch that.";
        fullRawResponse = fallback;
        _ttsService.speak(fallback);
      }

      // Finalize UI State
      emit(VoiceStreamingResponse(inputText, fullRawResponse, true, _chatHistory));

      final formattedResponse = TextFormatterService().formatAIResponse(fullRawResponse);
      _chatHistory.add(VoiceChatMessage(
        id: messageId,
        text: formattedResponse,
        rawContent: fullRawResponse,
        formattedContent: formattedResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      emit(VoiceResponseReady(inputText, formattedResponse, _chatHistory));
      emit(VoiceSpeaking(formattedResponse, _chatHistory)); // State indicating speaking

      // --- WAIT FOR AUDIO TO FINISH ---
      print("Stream done. Waiting for TTS queue to drain...");
      await _ttsService.waitForCompletion();
      print("TTS drained. Restarting loop.");

      // Restart Loop
      _resetStateTimer?.cancel();
      _resetStateTimer = Timer(resetTimeout, () async {
        if (!isClosed) await startListening();
      });

    } catch (e) {
      print('Error in streaming response: $e');
      rethrow;
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
    await _ttsService.stop();
    super.close();
  }
}