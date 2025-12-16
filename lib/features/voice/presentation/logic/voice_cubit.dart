import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class VoiceInitial extends VoiceState { VoiceInitial() : super([]); }
class VoiceInitializing extends VoiceState {
  final String message;
  VoiceInitializing(List<VoiceChatMessage> chatHistory, {this.message = "Initializing..."}) : super(chatHistory);
}
class SpeechReady extends VoiceState { SpeechReady(List<VoiceChatMessage> chatHistory) : super(chatHistory); }
class SpeechUnavailable extends VoiceState { SpeechUnavailable(List<VoiceChatMessage> chatHistory) : super(chatHistory); }
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
class VoiceIdle extends VoiceState { VoiceIdle(List<VoiceChatMessage> chatHistory) : super(chatHistory); }
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

      // --- CRASH RECOVERY LOGIC ---
      final prefs = await SharedPreferences.getInstance();
      final bool hasCrashed = prefs.getBool('gpu_init_crash_marker') ?? false;

      if (hasCrashed && modelToLoad != null) {
        print("🚨 Detected previous native crash. Marking model '${modelToLoad.name}' as CPU Only.");

        modelToLoad = modelToLoad.copyWith(isGpuSupported: false);
        await _modelManagementService.addModel(modelToLoad);

        await prefs.setBool('gpu_init_crash_marker', false);
      }

      String initMessage = modelToLoad != null
          ? "Loading ${modelToLoad.name}..."
          : "Loading default model...";

      emit(VoiceInitializing(_chatHistory, message: initMessage));

      bool forceCpu = modelToLoad?.isGpuSupported == false;

      // We need to cast the repository to GemmaRepositoryImpl to access the extended initializeModel with forceCpu
      // Or update the interface. Assuming interface update:
      bool gemmaInitialized = await (_generateResponseUseCase.repository as GemmaRepositoryImpl).initializeModel(
          modelPath: modelToLoad?.address,
          forceCpu: forceCpu
      );

      if (!gemmaInitialized) {
        emit(VoiceError('Failed to load model.', _chatHistory));
        return;
      }

      final repoImpl = _generateResponseUseCase.repository as GemmaRepositoryImpl;
      bool actuallyUsedGpu = repoImpl.isUsingGpu;

      if (modelToLoad != null && modelToLoad.isGpuSupported != actuallyUsedGpu) {
        print("🧠 Testing Complete: Model '${modelToLoad.name}' uses GPU? $actuallyUsedGpu");
        final updatedModel = modelToLoad.copyWith(isGpuSupported: actuallyUsedGpu);
        await _modelManagementService.addModel(updatedModel);
      }

      bool speechAvailable = await _speechService.init();
      if (speechAvailable) {
        emit(SpeechReady(_chatHistory));
        if (!_isManualStop) {
          await startListening();
        }
      } else {
        emit(SpeechUnavailable(_chatHistory));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory));
    }
  }

  Future<void> switchModel(AIModel model) async {
    print("Switching to model: ${model.name}");

    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _speechService.stopListening();
    await _ttsService.stop();

    await Future.delayed(const Duration(milliseconds: 500));

    await _modelManagementService.setSelectedModelId(model.id);

    _isManualStop = false;

    await initializeServices(specificModel: model);
  }

  Future<AIModel?> pickAndAddModel({String? customName}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        String fileName = result.files.single.name;

        final newModel = AIModel(
          id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
          name: customName ?? fileName,
          address: path,
          isDefault: false,
          isGpuSupported: null,
        );

        await _modelManagementService.addModel(newModel);
        return newModel;
      }
      return null;
    } catch (e) {
      emit(VoiceError("Failed to pick file: $e", _chatHistory));
      return null;
    }
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;
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

  // Missing Method 1: stopListening
  Future<void> stopListening() async {
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _speechService.stopListening();
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory));
  }

  // Missing Method 2: stopSpeaking
  Future<void> stopSpeaking() async {
    _isManualStop = true;
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory));
  }

  // Missing Method 3: restartListening
  Future<void> restartListening() async {
    await startListening();
  }

  // Missing Method 4: clearChatHistory
  void clearChatHistory() {
    _chatHistory.clear();
    emit(VoiceIdle(_chatHistory));
  }

  void _handleListeningComplete() async {
    if (_isManualStop) return;
    final String originalText = _lastRecognizedText.trim();
    if (originalText.isEmpty) { _restartLoopImmediately(); return; }
    if (!originalText.toLowerCase().startsWith('jack')) { _restartLoopImmediately(); return; }

    String command = originalText.substring(4).trim().replaceAll(RegExp(r'^[,.?!:\s]+'), '');

    if (command.isEmpty) {
      _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: "Jack", isUser: true, timestamp: DateTime.now()));
      emit(VoiceResponseReady("Jack", "Yes?", _chatHistory));
      await _ttsService.speak("Yes?");
      await _ttsService.waitForCompletion();
      if (!_isManualStop) await startListening();
      return;
    }

    _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: originalText, isUser: true, timestamp: DateTime.now()));
    emit(VoiceProcessing(originalText, _chatHistory));

    try { await _generateStreamingResponse(command); }
    catch (e) { _handleErrorAndRestart(); }
  }

  void _restartLoopImmediately() {
    emit(VoiceIdle(_chatHistory));
    _resetStateTimer?.cancel();
    _resetStateTimer = Timer(resetTimeout, () async { if (!isClosed && !_isManualStop) await startListening(); });
  }

  void _handleErrorAndRestart() async {
    String error = "I'm sorry, I encountered an error.";
    _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: error, isUser: false, timestamp: DateTime.now()));
    emit(VoiceResponseReady("", error, _chatHistory));
    await _ttsService.speak(error);
    await _ttsService.waitForCompletion();
    if (!_isManualStop) await startListening();
  }

  Future<void> _generateStreamingResponse(String inputText) async {
    String fullRawResponse = '';
    String sentenceBuffer = '';
    final streamMessageId = 'stream_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // *** CRITICAL: Stop listening BEFORE starting TTS ***
      await _speechService.stopListening();

      await for (String token in _generateResponseUseCase.callStreaming(inputText)) {
        if (_isManualStop) break;
        fullRawResponse += token;
        sentenceBuffer += token;

        if (RegExp(r'[.?!:]').hasMatch(token) || RegExp(r'[.?!:]\s$').hasMatch(sentenceBuffer)) {
          if (sentenceBuffer.trim().length > 1) {
            _ttsService.speak(TextFormatterService().formatForTTS(sentenceBuffer));
            sentenceBuffer = '';
          }
        }

        final msg = VoiceChatMessage(
            id: streamMessageId,
            text: fullRawResponse,
            rawContent: fullRawResponse,
            isUser: false,
            timestamp: DateTime.now()
        );
        emit(VoiceStreamingResponse(inputText, fullRawResponse, false, [..._chatHistory, msg]));
      }

      if (_isManualStop) return;

      if (sentenceBuffer.trim().isNotEmpty) {
        _ttsService.speak(TextFormatterService().formatForTTS(sentenceBuffer));
      }
      if (fullRawResponse.trim().isEmpty) {
        _ttsService.speak("I didn't quite catch that.");
      }

      final formatted = TextFormatterService().formatAIResponse(fullRawResponse);
      final finalMsg = VoiceChatMessage(
          id: streamMessageId,
          text: formatted,
          rawContent: fullRawResponse,
          formattedContent: formatted,
          isUser: false,
          timestamp: DateTime.now()
      );
      _chatHistory.add(finalMsg);

      emit(VoiceResponseReady(inputText, formatted, _chatHistory));
      emit(VoiceSpeaking(formatted, _chatHistory));

      // *** CRITICAL: Wait for TTS to complete BEFORE restarting listening ***
      await _ttsService.waitForCompletion();

      // Add a small delay to ensure audio pipeline is clear
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isManualStop) _restartLoopImmediately();
    } catch (e) {
      rethrow;
    }
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