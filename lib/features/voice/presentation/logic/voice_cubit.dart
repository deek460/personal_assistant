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

  Timer? _resetStateTimer;
  static const Duration resetTimeout = Duration(milliseconds: 200); // Faster restart for invalid inputs

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
    _isManualStop = true;
    _resetStateTimer?.cancel();

    await _speechService.stopListening();
    await _ttsService.stop();

    emit(VoiceIdle(_chatHistory));
  }

  void _handleListeningComplete() async {
    if (_isManualStop) return;

    final String originalText = _lastRecognizedText.trim();

    // 1. Check for Silence
    if (originalText.isEmpty) {
      _restartLoopImmediately();
      return;
    }

    // 2. PSEUDO-WAKE WORD CHECK ("Jack")
    // Normalize logic: check if text starts with "jack" (case insensitive)
    final bool hasWakeWord = originalText.toLowerCase().startsWith('jack');

    if (!hasWakeWord) {
      print('Ignored input (Missing "Jack"): $originalText');
      // If we didn't hear "Jack", we ignore and restart listening immediately.
      // We do NOT update UI history for ignored commands.
      _restartLoopImmediately();
      return;
    }

    // 3. Process the Command (Strip "Jack")
    // Remove "Jack" from the start (first 4 chars)
    String command = originalText.substring(4).trim();

    // Clean leading punctuation (e.g., "Jack, tell me..." -> ", tell me..." -> "tell me...")
    command = command.replaceAll(RegExp(r'^[,.?!:\s]+'), '');

    // 4. Check if Command is Empty (User just said "Jack")
    if (command.isEmpty) {
      print('User said only "Jack". Asking for input.');

      // Update UI
      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Jack",
        isUser: true,
        timestamp: DateTime.now(),
      ));

      const response = "Yes?";
      emit(VoiceResponseReady("Jack", response, _chatHistory)); // Brief flash state

      // Speak "Yes?" and then listen again
      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();

      if (!_isManualStop) await startListening();
      return;
    }

    // --- PROCEED WITH VALID COMMAND ---

    // Update history with the FULL recognized text (including Jack for context) or just command?
    // Let's show full text "Jack, what is..." so user knows it was heard.
    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: originalText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    emit(VoiceProcessing(originalText, _chatHistory));

    try {
      await _generateStreamingResponse(command); // Pass only command to AI
    } catch (e) {
      print('VoiceCubit: Error: $e');
      _handleErrorAndRestart();
    }
  }

  void _restartLoopImmediately() {
    // Brief flicker to Idle to indicate reset, then start
    emit(VoiceIdle(_chatHistory));
    _resetStateTimer?.cancel();
    _resetStateTimer = Timer(resetTimeout, () async {
      if (!isClosed && !_isManualStop) await startListening();
    });
  }

  void _handleErrorAndRestart() async {
    String errorResponse = "I'm sorry, I encountered an error.";
    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: errorResponse,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    emit(VoiceResponseReady("", errorResponse, _chatHistory));
    await _ttsService.speak(errorResponse);
    await _ttsService.waitForCompletion();
    if (!_isManualStop) await startListening();
  }

  Future<void> _generateStreamingResponse(String inputText) async {
    String fullRawResponse = '';
    String sentenceBuffer = '';
    final streamMessageId = 'stream_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await for (String token in _generateResponseUseCase.callStreaming(inputText)) {
        if (_isManualStop) break;

        fullRawResponse += token;
        sentenceBuffer += token;

        // Simultaneous TTS
        if (RegExp(r'[.?!:]').hasMatch(token) || RegExp(r'[.?!:]\s$').hasMatch(sentenceBuffer)) {
          if (sentenceBuffer.trim().length > 1) {
            final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
            _ttsService.speak(cleanSentence);
            sentenceBuffer = '';
          }
        }

        // UI Update
        final streamingMessage = VoiceChatMessage(
          id: streamMessageId,
          text: fullRawResponse,
          rawContent: fullRawResponse,
          isUser: false,
          timestamp: DateTime.now(),
        );

        emit(VoiceStreamingResponse(
            inputText,
            fullRawResponse,
            false,
            [..._chatHistory, streamingMessage]
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

      // Finalize
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

      await _ttsService.waitForCompletion();

      if (!_isManualStop) {
        _restartLoopImmediately();
      }

    } catch (e) {
      print('Error in streaming response: $e');
      rethrow;
    }
  }

  Future<void> stopSpeaking() async {
    _isManualStop = true;
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