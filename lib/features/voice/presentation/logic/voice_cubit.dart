import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../data/models/voice_chat_message.dart';
import '../../../gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../../../../core/services/text_formatter_service.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';

abstract class VoiceState {
  final List<VoiceChatMessage> chatHistory;
  VoiceState(this.chatHistory);
}

class VoiceInitial extends VoiceState {
  VoiceInitial() : super([]);
}

class VoiceInitializing extends VoiceState {
  final String message;
  VoiceInitializing(List<VoiceChatMessage> chatHistory, {this.message = "Initializing..."}) : super(chatHistory);
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
  final ModelManagementService _modelManagementService = ModelManagementService();

  String _lastRecognizedText = '';
  List<VoiceChatMessage> _chatHistory = [];
  Timer? _resetStateTimer;
  static const Duration resetTimeout = Duration(milliseconds: 200);
  bool _isManualStop = false;

  VoiceCubit(
      this._speechService,
      this._ttsService,
      this._generateResponseUseCase,
      ) : super(VoiceInitial());

  Future<void> initializeServices({AIModel? specificModel}) async {
    emit(VoiceInitializing(_chatHistory, message: "Checking permissions..."));

    try {
      await _requestStoragePermission();

      AIModel? modelToLoad = specificModel;
      if (modelToLoad == null) {
        modelToLoad = await _modelManagementService.getSelectedModel();
      }

      String initMessage = modelToLoad != null
          ? "Loading ${modelToLoad.name}..."
          : "Loading default model...";

      emit(VoiceInitializing(_chatHistory, message: initMessage));

      bool gemmaInitialized = await _generateResponseUseCase.repository.initializeModel(
          modelPath: modelToLoad?.address
      );

      if (!gemmaInitialized) {
        emit(VoiceError('Failed to load model. Please select a valid .task file.', _chatHistory));
        return;
      }

      bool speechAvailable = await _speechService.init();
      if (speechAvailable) {
        emit(SpeechReady(_chatHistory));
        await startListening();
      } else {
        emit(SpeechUnavailable(_chatHistory));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory));
    }
  }

  Future<void> switchModel(AIModel model) async {
    print("Switching to model: ${model.name} at ${model.address}");
    await stopListening();
    await _modelManagementService.setSelectedModelId(model.id);
    await initializeServices(specificModel: model);
  }

  // Updated to accept custom name and return the model
  Future<AIModel?> pickAndAddModel({String? customName}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        String fileName = result.files.single.name;

        final newModel = AIModel(
          id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
          name: customName ?? fileName, // Use custom name if provided
          address: path,
          isDefault: false,
        );

        await _modelManagementService.addModel(newModel);

        // Return the model so UI can select it
        return newModel;
      } else {
        print("File picking canceled");
        return null;
      }
    } catch (e) {
      emit(VoiceError("Failed to pick file: $e", _chatHistory));
      return null;
    }
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;
    print("WARNING: Storage permissions denied.");
  }

  Future<void> startListening() async {
    _isManualStop = false;
    if (_ttsService.isSpeaking) await _ttsService.stop();

    _lastRecognizedText = '';
    emit(VoiceListening("", _chatHistory));
    _resetStateTimer?.cancel();

    await _speechService.startListening(
      onResult: (words) {
        _lastRecognizedText = words;
        emit(VoiceListening(words, _chatHistory));
      },
      onSessionComplete: () {
        if (!_isManualStop) _handleListeningComplete();
      },
    );
  }

  Future<void> stopListening() async {
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _speechService.stopListening();
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory));
  }

  void _handleListeningComplete() async {
    if (_isManualStop) return;
    final String originalText = _lastRecognizedText.trim();

    if (originalText.isEmpty) {
      _restartLoopImmediately();
      return;
    }

    final bool hasWakeWord = originalText.toLowerCase().startsWith('jack');
    if (!hasWakeWord) {
      _restartLoopImmediately();
      return;
    }

    String command = originalText.substring(4).trim();
    command = command.replaceAll(RegExp(r'^[,.?!:\s]+'), '');

    if (command.isEmpty) {
      _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Jack",
        isUser: true,
        timestamp: DateTime.now(),
      ));

      const response = "Yes?";
      emit(VoiceResponseReady("Jack", response, _chatHistory));
      await _ttsService.speak(response);
      await _ttsService.waitForCompletion();
      if (!_isManualStop) await startListening();
      return;
    }

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: originalText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    emit(VoiceProcessing(originalText, _chatHistory));

    try {
      await _generateStreamingResponse(command);
    } catch (e) {
      _handleErrorAndRestart();
    }
  }

  void _restartLoopImmediately() {
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

        if (RegExp(r'[.?!:]').hasMatch(token) || RegExp(r'[.?!:]\s$').hasMatch(sentenceBuffer)) {
          if (sentenceBuffer.trim().length > 1) {
            final cleanSentence = TextFormatterService().formatForTTS(sentenceBuffer);
            _ttsService.speak(cleanSentence);
            sentenceBuffer = '';
          }
        }

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

      if (!_isManualStop) _restartLoopImmediately();

    } catch (e) {
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