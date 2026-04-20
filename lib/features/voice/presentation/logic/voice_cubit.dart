import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../../../core/services/wake_word_service.dart'; // 🔴 RESTORED IMPORT
import '../../data/models/voice_chat_message.dart';
import '../../../gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../../../../core/services/text_formatter_service.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

abstract class VoiceState {
  final List<VoiceChatMessage> chatHistory;
  final String? pendingImagePath;
  final bool isLiveVisionEnabled;
  final CameraController? cameraController;

  VoiceState(this.chatHistory, {this.pendingImagePath, this.isLiveVisionEnabled = false, this.cameraController});
}

class VoiceInitial extends VoiceState { VoiceInitial() : super([]); }

class VoiceInitializing extends VoiceState {
  final String message;
  VoiceInitializing(List<VoiceChatMessage> chatHistory, {this.message = "Initializing...", String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
// 🔴 RESTORED SENTINEL STATE
class VoiceWaitingForWakeWord extends VoiceState {
  VoiceWaitingForWakeWord(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class SpeechReady extends VoiceState {
  SpeechReady(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class SpeechUnavailable extends VoiceState {
  SpeechUnavailable(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceListening extends VoiceState {
  final String recognizedWords;
  VoiceListening(this.recognizedWords, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceProcessing extends VoiceState {
  final String inputText;
  VoiceProcessing(this.inputText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceStreamingResponse extends VoiceState {
  final String inputText;
  final String partialResponse;
  final bool isComplete;
  VoiceStreamingResponse(this.inputText, this.partialResponse, this.isComplete, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceResponseReady extends VoiceState {
  final String inputText;
  final String responseText;
  VoiceResponseReady(this.inputText, this.responseText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceSpeaking extends VoiceState {
  final String responseText;
  VoiceSpeaking(this.responseText, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceIdle extends VoiceState {
  VoiceIdle(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceError extends VoiceState {
  final String errorMessage;
  VoiceError(this.errorMessage, List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceSettingsUpdated extends VoiceState {
  VoiceSettingsUpdated(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}
class VoiceImageAttached extends VoiceState {
  VoiceImageAttached(List<VoiceChatMessage> chatHistory, {String? pendingImagePath, bool isLiveVisionEnabled = false, CameraController? cameraController})
      : super(chatHistory, pendingImagePath: pendingImagePath, isLiveVisionEnabled: isLiveVisionEnabled, cameraController: cameraController);
}

class VoiceCubit extends Cubit<VoiceState> {
  final SpeechToTextService _speechService;
  final TextToSpeechService _ttsService;
  final WakeWordService _wakeWordService; // 🔴 RESTORED WAKE WORD INSTANCE
  final GenerateResponseUseCase _generateResponseUseCase;
  final ModelManagementService _modelManagementService = ModelManagementService();

  String _lastRecognizedText = '';
  List<VoiceChatMessage> _chatHistory = [];
  Timer? _resetStateTimer;
  static const Duration resetTimeout = Duration(milliseconds: 200);
  bool _isManualStop = false;

  String? _pendingImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  bool _isLiveVisionEnabled = false;

  List<String> _wakeWords = [];
  String _selectedWakeWord = 'jarvis'; // Default to lilly
  List<dynamic> _availableVoices = [];
  Map<String, String>? _currentVoice;

  // 🔴 RESTORED CONSTRUCTOR SIGNATURE
  VoiceCubit(
      this._speechService,
      this._ttsService,
      this._wakeWordService,
      this._generateResponseUseCase,
      ) : super(VoiceInitial());

  List<String> get wakeWords => _wakeWords;
  String get selectedWakeWord => _selectedWakeWord;
  List<dynamic> get availableVoices => _availableVoices;
  Map<String, String>? get currentVoice => _currentVoice;
  String? get pendingImagePath => _pendingImagePath;
  bool get isLiveVisionEnabled => _isLiveVisionEnabled;
  CameraController? get cameraController => _cameraController;

  Future<void> toggleLiveVision() async {
    if (_isLiveVisionEnabled) {
      _isLiveVisionEnabled = false;
      await _cameraController?.dispose();
      _cameraController = null;
      emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _cameraController = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
          await _cameraController!.initialize();
          _isLiveVisionEnabled = true;
          emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
        }
      } catch (e) {
        emit(VoiceError("Failed to start camera: $e", _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        _pendingImagePath = image.path;
        emit(VoiceImageAttached(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

        await _ttsService.speak("Image attached. Ask me about it.");
        await _ttsService.waitForCompletion();
        if (!_isManualStop) await startActiveDictation();
      }
    } catch (e) {
      emit(VoiceError("Failed to attach image: $e", _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    }
  }

  void clearPendingImage() {
    _pendingImagePath = null;
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
  }

  Future<void> processTextCommand(String command) async {
    await _wakeWordService.stopListening();
    await _speechService.stopListening();

    String? attachedImage = _pendingImagePath;
    _pendingImagePath = null;

    if (_isLiveVisionEnabled && attachedImage == null && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        attachedImage = xFile.path;
      } catch (e) {}
    }

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: command,
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: attachedImage,
    ));
    emit(VoiceProcessing(command, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

    try {
      await _generateStreamingResponse(command, imagePath: attachedImage);
    } catch (e) {
      _handleErrorAndRestart();
    }
  }

  Future<void> initializeServices({AIModel? specificModel}) async {
    emit(VoiceInitializing(_chatHistory, message: "Checking permissions...", pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

    try {
      await _requestPermissions();

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
        modelToLoad = modelToLoad.copyWith(isGpuSupported: false);
        await _modelManagementService.addModel(modelToLoad);
        await prefs.setBool('gpu_init_crash_marker', false);
      }

      String initMessage = modelToLoad != null
          ? "Loading ${modelToLoad.name}..."
          : "Loading default model...";

      emit(VoiceInitializing(_chatHistory, message: initMessage, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

      bool forceCpu = modelToLoad?.isGpuSupported == false;

      bool gemmaInitialized = await (_generateResponseUseCase.repository as GemmaRepositoryImpl).initializeModel(
          modelPath: modelToLoad?.address,
          forceCpu: forceCpu
      );

      if (!gemmaInitialized) {
        emit(VoiceError('Failed to load model.', _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
        return;
      }

      final repoImpl = _generateResponseUseCase.repository as GemmaRepositoryImpl;
      bool actuallyUsedGpu = repoImpl.isUsingGpu;

      if (modelToLoad != null && modelToLoad.isGpuSupported != actuallyUsedGpu) {
        final updatedModel = modelToLoad.copyWith(isGpuSupported: actuallyUsedGpu);
        await _modelManagementService.addModel(updatedModel);
      }

      // 🔴 INIT BOTH ENGINES
      bool speechAvailable = await _speechService.init();

      if (speechAvailable) {
        emit(SpeechReady(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
        if (!_isManualStop) {
          await startSentinelMode();
        }
      } else {
        emit(SpeechUnavailable(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      }
    } catch (e) {
      emit(VoiceError('Initialization failed: $e', _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    }
  }

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
        await setSelectedWakeWord(_wakeWords.isNotEmpty ? _wakeWords.first : 'jarvis');
      } else {
        emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      }
    }
  }

  Future<void> setSelectedWakeWord(String word) async {
    if (_wakeWords.contains(word)) {
      _selectedWakeWord = word;
      await _modelManagementService.saveSelectedWakeWord(word);

      // 🔴 RESTART SENTINEL IMMEDIATELY SO IT LOADS THE NEW .ONNX FILE
      if (state is VoiceWaitingForWakeWord) {
        await startSentinelMode();
      }
      emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    }
  }

  Future<void> updateVoice(Map<String, String> voice) async {
    _currentVoice = voice;
    await _ttsService.setVoice(voice);
    await _modelManagementService.saveSelectedVoice(voice);
    emit(VoiceSettingsUpdated(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
  }

  Future<void> switchModel(AIModel model) async {
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _wakeWordService.stopListening();
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
      emit(VoiceError("Failed to pick file: $e", _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      return null;
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    if (await Permission.manageExternalStorage.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;
  }

  // 🔴 RESTORED HYBRID ARCHITECTURE (ONNX -> STT)
// AFTER:
  Future<void> startSentinelMode() async {
    _isManualStop = false;
    await _speechService.stopListening(); // Ensure STT is dead

    emit(VoiceWaitingForWakeWord(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

    // First call: register the instance. Subsequent calls: just resume the audio loop.
    bool success;
    if (_wakeWordService.isListening == false && !_wakeWordService.isInitialized) {
      success = await _wakeWordService.startListening(
          wakeWord: _selectedWakeWord,
          onDetect: _onWakeWordDetected
      );
    } else {
      await _wakeWordService.resumeListening();
      success = true;
    }

    if (!success) {
      String errorMsg = "Model file '${_selectedWakeWord.toLowerCase()}.onnx' is missing. Please add the file or select another wake word.";
      _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: errorMsg, isUser: false, timestamp: DateTime.now()));
      emit(VoiceError(errorMsg, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    }
  }

  void _onWakeWordDetected() async {
    if (_isManualStop) return;
    print("Detected Lilly");
    await _wakeWordService.pauseListening(); // Kill ONNX to free Mic
    await Future.delayed(const Duration(milliseconds: 300));

    String displayWake = _selectedWakeWord[0].toUpperCase() + _selectedWakeWord.substring(1);
    _chatHistory.add(VoiceChatMessage(
        id: DateTime.now().toString(),
        text: displayWake,
        isUser: true,
        timestamp: DateTime.now()
    ));

    emit(VoiceResponseReady(displayWake, "Yes?", _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    await _ttsService.speak("Yes?");
    await _ttsService.waitForCompletion();

    if (!_isManualStop) {
      await startActiveDictation();
    }
  }

  Future<void> startActiveDictation() async {
    _isManualStop = false;
    await _wakeWordService.stopListening();
    if (_ttsService.isSpeaking) await _ttsService.stop();
    _lastRecognizedText = '';
    emit(VoiceListening("", _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    _resetStateTimer?.cancel();
    await _speechService.startListening(
      onResult: (words) {
        _lastRecognizedText = words;
        emit(VoiceListening(words, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      },
      onSessionComplete: () {
        if (!_isManualStop) _handleDictationComplete();
      },
    );
  }

  Future<void> stopListening() async {
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _wakeWordService.stopListening();
    await _speechService.stopListening();
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
  }

  Future<void> stopSpeaking() async {
    _isManualStop = true;
    await _ttsService.stop();
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
  }

  void clearChatHistory() {
    _chatHistory.clear();
    emit(VoiceIdle(_chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
  }

  void _handleDictationComplete() async {
    if (_isManualStop) return;
    _speechService.pauseListening();

    String command = _lastRecognizedText.trim().replaceAll(RegExp(r'^[,.?!:\s]+'), '');

    if (command.isEmpty) {
      // 🔴 RETURN TO ONNX SENTINEL
      await startSentinelMode();
      return;
    }

    String? attachedImage = _pendingImagePath;
    _pendingImagePath = null;

    if (_isLiveVisionEnabled && attachedImage == null && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        attachedImage = xFile.path;
      } catch (e) {}
    }

    _chatHistory.add(VoiceChatMessage(
      id: DateTime.now().toString(),
      text: _lastRecognizedText,
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: attachedImage,
    ));
    emit(VoiceProcessing(_lastRecognizedText, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

    try { await _generateStreamingResponse(command, imagePath: attachedImage); }
    catch (e) { _handleErrorAndRestart(); }
  }

  void _handleErrorAndRestart() async {
    _speechService.pauseListening();
    String error = "I'm sorry, I encountered an error.";
    _chatHistory.add(VoiceChatMessage(id: DateTime.now().toString(), text: error, isUser: false, timestamp: DateTime.now()));
    emit(VoiceResponseReady("", error, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
    await _ttsService.speak(error);
    await _ttsService.waitForCompletion();
    if (!_isManualStop) await startSentinelMode();
  }

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
        emit(VoiceStreamingResponse(inputText, fullRawResponse, false, [..._chatHistory, msg], pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
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

      emit(VoiceResponseReady(inputText, formatted, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));
      emit(VoiceSpeaking(formatted, _chatHistory, pendingImagePath: _pendingImagePath, isLiveVisionEnabled: _isLiveVisionEnabled, cameraController: _cameraController));

      await _ttsService.waitForCompletion();

      // 🔴 RETURN TO ONNX SENTINEL
      if (!_isManualStop) await startSentinelMode();
    } catch (e) { rethrow; }
  }

  @override
  Future<void> close() async {
    _isManualStop = true;
    _resetStateTimer?.cancel();
    await _cameraController?.dispose();
    await _wakeWordService.stopListening();
    await _speechService.stopListening();
    await _ttsService.stop();
    await _generateResponseUseCase.repository.disposeModel();
    super.close();
  }
}