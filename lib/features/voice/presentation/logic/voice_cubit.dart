import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // NEW IMPORT
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../data/models/voice_chat_message.dart';
import '../../../gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../../../../core/services/text_formatter_service.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

// --- STATES UPDATED TO HOLD PENDING IMAGE PATH ---
abstract class VoiceState {
  final List<VoiceChatMessage> chatHistory;
  final String? pendingImagePath;
  VoiceState(this.chatHistory, {this.pendingImagePath});
}

class VoiceInitial extends VoiceState { VoiceInitial() : super([]); }
class VoiceInitializing extends VoiceState {
  final String message;
  VoiceInitializing(List<VoiceChatMessage> chatHistory, {this.message = "Initializing...", String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class SpeechReady extends VoiceState { SpeechReady(List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath); }
class SpeechUnavailable extends VoiceState { SpeechUnavailable(List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath); }
class VoiceListening extends VoiceState {
  final String recognizedWords;
  VoiceListening(this.recognizedWords, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceProcessing extends VoiceState {
  final String inputText;
  VoiceProcessing(this.inputText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceStreamingResponse extends VoiceState {
  final String inputText;
  final String partialResponse;
  final bool isComplete;
  VoiceStreamingResponse(this.inputText, this.partialResponse, this.isComplete, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceResponseReady extends VoiceState {
  final String inputText;
  final String responseText;
  VoiceResponseReady(this.inputText, this.responseText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceSpeaking extends VoiceState {
  final String responseText;
  VoiceSpeaking(this.responseText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceIdle extends VoiceState { VoiceIdle(List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath); }
class VoiceError extends VoiceState {
  final String errorMessage;
  VoiceError(this.errorMessage, List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceSettingsUpdated extends VoiceState {
  VoiceSettingsUpdated(List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
}
class VoiceImageAttached extends VoiceState {
  VoiceImageAttached(List<VoiceChatMessage> chatHistory, {String? pendingImagePath}) : super(chatHistory, pendingImagePath: pendingImagePath);
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

  // -- Image State --
  String? _pendingImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  // -- Settings State --
  List<String> _wakeWords = [];
  String _selectedWakeWord = 'jack'; // Default
  List<dynamic> _availableVoices = [];
  Map<String, String>? _currentVoice;

  VoiceCubit(
      this._speechService,
      this._ttsService,
      this._generateResponseUseCase,
      ) : super(VoiceInitial());

  // Getters for UI
  List<String> get wakeWords => _wakeWords;
  String get selectedWakeWord => _selectedWakeWord;
  List<dynamic> get availableVoices => _availableVoices;
  Map<String, String>? get currentVoice => _currentVoice;
  String? get pendingImagePath => _pendingImagePath;

  // --- Image Handling Methods ---
  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        _pendingImagePath = image.path;
        emit(VoiceImageAttached(_chatHistory, pendingImagePath: _pendingImagePath));

        // Let the user know the image is ready
        await _ttsService.speak("Image attached. Ask me about it.");
        if (!_isManualStop) await startListening();
      }
    } catch (e) {
      emit(VoiceError("Failed to attach image: $e", _chatHistory, pendingImagePath: _pendingImagePath));
    }
  }

  void clearPendingImage() {
    _pendingImagePath = null;
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath));
  }

  Future<void> processTextCommand(String command) async {
    print("VoiceCubit: Processing injected command: $command");

    // Capture image before clearing it from the pending state
    final attachedImage = _pendingImagePath;
    _pendingImagePath = null;

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: command,
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: attachedImage,
    ));
    emit(VoiceProcessing(command, _chatHistory, pendingImagePath: _pendingImagePath));

    try {
      await _generateStreamingResponse(command, imagePath: attachedImage);
    } catch (e) {
      _handleErrorAndRestart();
    }
  }

  Future<void> initializeServices({AIModel? specificModel}) async {
    emit(VoiceInitializing(_chatHistory, message: "Checking permissions...", pendingImagePath: _pendingImagePath));

    try {
      await _requestStoragePermission();

      // Load Settings
      _wakeWords = await _modelManagementService.getWakeWords();
      _selectedWakeWord = await _modelManagementService.getSelectedWakeWord();
      _availableVoices = await _ttsService.getAvailableVoices();
      final savedVoice = await _modelManagementService.getSelectedVoice();
      if (savedVoice != null) {
        _currentVoice = savedVoice;
        await _ttsService.setVoice(savedVoice);
      }

      AIModel? modelToLoad = specificModel;
      modelToLoad ??= await _modelManagementService.getSelectedModel();

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

      emit(VoiceInitializing(_chatHistory, message: initMessage, pendingImagePath: _pendingImagePath));

      bool forceCpu = modelToLoad?.isGpuSupported == false;

      bool gemmaInitialized = await (_generateResponseUseCase.repository as GemmaRepositoryImpl).initializeModel(
          modelPath: modelToLoad?.address,
          forceCpu: forceCpu
      );

      if (!gemmaInitialized) {
        emit(VoiceError('Failed to load model.', _chatHistory, pendingImagePath: _pendingImagePath));
        return;
      }

      final repoImpl = _generateResponseUseCase.repository as GemmaRepositoryImpl;
      bool actuallyUsedGpu = repoImpl.isUsingGpu;

      if (modelToLoad != null && modelToLoad.isGpuSupported != actuallyUsedGpu) {
        final updatedModel = modelToLoad.copyWith(isGpuSupported: actuallyUsedGpu);
        await _modelManagementService.addModel(updatedModel);
      }

      bool speechAvailable = await _speechService.init();
      if (speechAvailable) {
        emit(SpeechReady(_chatHistory, pendingImagePath: _pendingImagePath));
        if (!_isManualStop) {
          await startListening();
        }
      } else {
        emit(SpeechUnavailable(_chatHistory, pendingImagePath: _pendingImagePath));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory, pendingImagePath: _pendingImagePath));
    }
  }

  // --- Settings Management Methods ---

  Future<void> addWakeWord(String word) async {
    if (word.trim().isEmpty) return;
    final lower = word.trim().toLowerCase();
    if (!_wakeWords.contains(lower)) {
      _wakeWords.add(lower);
      await _modelManagementService.saveWakeWords(_wakeWords);
      await setSelectedWakeWord(lower);
    }
  }

  Future<void> removeWakeWord(String word) async {
    if (_wakeWords.contains(word)) {
      _wakeWords.remove(word);
      await _modelManagementService.saveWakeWords(_wakeWords);
      if (_selectedWakeWord == word) {
        await setSelectedWakeWord(_wakeWords.isNotEmpty ? _wakeWords.first : 'jack');
      } else {
        emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath));
      }
    }
  }

  Future<void> setSelectedWakeWord(String word) async {
    if (_wakeWords.contains(word)) {
      _selectedWakeWord = word;
      await _modelManagementService.saveSelectedWakeWord(word);
      emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath));
    }
  }

  Future<void> updateVoice(Map<String, String> voice) async {
    _currentVoice = voice;
    await _ttsService.setVoice(voice);
    await _modelManagementService.saveSelectedVoice(voice);
    emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath));
  }

  // --- End Settings Management ---

  Future<void> switchModel(AIModel model) async {
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
      emit(VoiceError("Failed to pick file: $e", _chatHistory, pendingImagePath: _pendingImagePath));
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
    emit(VoiceListening("", _chatHistory, pendingImagePath: _pendingImagePath));
    _resetStateTimer?.cancel();
    await _speechService.startListening(
      onResult: (words) {
        _lastRecognizedText = words;
        emit(VoiceListening(words, _chatHistory, pendingImagePath: _pendingImagePath));
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
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath));
  }

  Future<void> stopSpeaking() async {
    _isManualStop = true;
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath));
  }

  Future<void> restartListening() async {
    await startListening();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath));
  }

  void _handleListeningComplete() async {
    if (_isManualStop) return;

    _speechService.pauseListening();

    final String originalText = _lastRecognizedText.trim().toLowerCase();
    bool matchFound = originalText.startsWith(_selectedWakeWord);

    if (!matchFound || originalText.isEmpty) {
      _restartLoopImmediately();
      return;
    }

    String command = originalText.substring(_selectedWakeWord.length).trim().replaceAll(RegExp(r'^[,.?!:\s]+'), '');

    if (command.isEmpty) {
      String displayWake = _selectedWakeWord[0].toUpperCase() + _selectedWakeWord.substring(1);

      // Do NOT consume the pending image if they just said the wake word
      _chatHistory.add(VoiceChatMessage(
          id: DateTime.now().toString(),
          text: displayWake,
          isUser: true,
          timestamp: DateTime.now()
      ));

      emit(VoiceResponseReady(displayWake, "Yes?", _chatHistory, pendingImagePath: _pendingImagePath));
      await _ttsService.speak("Yes?");
      await _ttsService.waitForCompletion();
      if (!_isManualStop) await startListening();
      return;
    }

    // Capture the pending image to send it
    final attachedImage = _pendingImagePath;
    _pendingImagePath = null;

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().toString(),
      text: _lastRecognizedText,
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: attachedImage, // Bind image
    ));
    emit(VoiceProcessing(_lastRecognizedText, _chatHistory, pendingImagePath: _pendingImagePath));

    try { await _generateStreamingResponse(command, imagePath: attachedImage); }
    catch (e) { _handleErrorAndRestart(); }
  }

  void _restartLoopImmediately() {
    if (state is! VoiceSettingsUpdated && state is! VoiceImageAttached) {
      emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath));
    }
    _resetStateTimer?.cancel();
    _resetStateTimer = Timer(resetTimeout, () async { if (!isClosed && !_isManualStop) await startListening(); });
  }

  void _handleErrorAndRestart() async {
    _speechService.pauseListening();
    String error = "I'm sorry, I encountered an error.";
    _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: error, isUser: false, timestamp: DateTime.now()));
    emit(VoiceResponseReady("", error, _chatHistory, pendingImagePath: _pendingImagePath));
    await _ttsService.speak(error);
    await _ttsService.waitForCompletion();
    if (!_isManualStop) await startListening();
  }

  // UPDATED: Now receives the imagePath
  Future<void> _generateStreamingResponse(String inputText, {String? imagePath}) async {
    String fullRawResponse = '';
    String sentenceBuffer = '';
    final streamMessageId = 'stream_${DateTime.now().millisecondsSinceEpoch}';

    final trace = FirebasePerformance.instance.newTrace('ai_response_generation');
    await trace.start();

    final repo = _generateResponseUseCase.repository as GemmaRepositoryImpl;
    trace.putAttribute('backend_type', repo.isUsingGpu ? 'GPU' : 'CPU');
    trace.putAttribute('input_length', inputText.length.toString());
    if (imagePath != null) trace.putAttribute('has_image', 'true');

    final DateTime startTime = DateTime.now();
    Duration? firstTokenLatency;

    try {
      // Pass imagePath through to the domain layer
      await for (String token in _generateResponseUseCase.callStreaming(inputText, imagePath: imagePath)) {
        if (_isManualStop) break;

        if (firstTokenLatency == null) {
          firstTokenLatency = DateTime.now().difference(startTime);
          trace.setMetric('time_to_first_token_ms', firstTokenLatency.inMilliseconds);
        }

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
          timestamp: DateTime.now(),
          latency: firstTokenLatency,
        );
        emit(VoiceStreamingResponse(inputText, fullRawResponse, false, [..._chatHistory, msg], pendingImagePath: _pendingImagePath));
      }

      if (_isManualStop) return;
      if (sentenceBuffer.trim().isNotEmpty) _ttsService.speak(TextFormatterService().formatForTTS(sentenceBuffer));
      if (fullRawResponse.trim().isEmpty) _ttsService.speak("I didn't quite catch that.");

      final formatted = TextFormatterService().formatAIResponse(fullRawResponse);
      final finalMsg = VoiceChatMessage(
        id: streamMessageId,
        text: formatted,
        rawContent: fullRawResponse,
        formattedContent: formatted,
        isUser: false,
        timestamp: DateTime.now(),
        latency: firstTokenLatency,
      );
      _chatHistory.add(finalMsg);

      trace.setMetric('response_char_count', fullRawResponse.length);
      trace.putAttribute('status', 'success');
      await trace.stop();

      emit(VoiceResponseReady(inputText, formatted, _chatHistory, pendingImagePath: _pendingImagePath));
      emit(VoiceSpeaking(formatted, _chatHistory, pendingImagePath: _pendingImagePath));

      await _ttsService.waitForCompletion();

      _speechService.resumeListening();
      if (!_isManualStop) _restartLoopImmediately();
    } catch (e) { rethrow; }
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