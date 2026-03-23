import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../domain/repositories/gemma_repository.dart';
import '../../../../core/services/text_formatter_service.dart';
import '../../../../core/services/image_processing_service.dart'; // NEW IMPORT

class GemmaRepositoryImpl implements GemmaRepository {
  InferenceModel? _inferenceModel;
  bool _isModelLoaded = false;

  PreferredBackend _currentBackend = PreferredBackend.gpu;
  static const String _crashMarkerKey = 'gpu_init_crash_marker';

  // Inject the ML Kit processing service
  final ImageProcessingService _imageService = ImageProcessingService();

  @override
  bool get isModelLoaded => _isModelLoaded;

  bool get isUsingGpu => _currentBackend == PreferredBackend.gpu;

  @override
  Future<bool> initializeModel({String? modelPath, bool forceCpu = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (forceCpu) {
      print("ℹ️ CPU backend forced by Logic Layer.");
      _currentBackend = PreferredBackend.cpu;
      return _attemptLoad(modelPath: modelPath, backend: PreferredBackend.cpu);
    }

    if (await _isProblematicDevice()) {
      print("⚠️ DETECTED INCOMPATIBLE HARDWARE. Forcing CPU Backend.");
      _currentBackend = PreferredBackend.cpu;
      return _attemptLoad(modelPath: modelPath, backend: PreferredBackend.cpu);
    }

    await prefs.setBool(_crashMarkerKey, true);

    _currentBackend = PreferredBackend.gpu;
    final success = await _attemptLoad(modelPath: modelPath, backend: PreferredBackend.gpu);

    if (success) {
      print("✅ GPU Init successful. Clearing crash marker.");
      await prefs.setBool(_crashMarkerKey, false);
    } else {
      await prefs.setBool(_crashMarkerKey, false);
    }

    return success;
  }

  Future<bool> _isProblematicDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final hardware = androidInfo.hardware.toLowerCase();
        final board = androidInfo.board.toLowerCase();
        final model = androidInfo.model.toLowerCase();

        if (hardware.contains('mt') || board.contains('mt') || hardware.contains('k68') || board.contains('k68')) {
          return true;
        }
        if (model.contains('m53') || model.contains('sm-m536')) {
          return true;
        }
      }
    } catch (e) {
      print("Error checking device info: $e");
    }
    return false;
  }

  Future<bool> _attemptLoad({String? modelPath, required PreferredBackend backend}) async {
    try {
      print('🤖 Initializing Gemma model with ${backend.toString()}...');

      await disposeModel();

      final gemma = FlutterGemmaPlugin.instance;
      final modelManager = gemma.modelManager;

      String? finalPath;

      if (modelPath != null && modelPath.isNotEmpty) {
        if (modelPath.startsWith('local://')) {
          final cleanPath = modelPath.replaceFirst('local://', '');

          if (File(cleanPath).existsSync()) {
            finalPath = cleanPath;
          }
        } else {
          if (File(modelPath).existsSync()) {
            finalPath = modelPath;
          }
        }
      }

      if (finalPath == null) {
        finalPath = await _findModelFile();
      }

      if (finalPath == null) {
        print('❌ Model file not found. Ensure model is in Downloads folder.');
        return false;
      }

      print('📦 Loading model from: $finalPath');
      await modelManager.setModelPath(finalPath);

      print(' Creating inference model...');
      _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: backend,
        maxTokens: 512,
      );

      _isModelLoaded = true;
      _currentBackend = backend;
      print('✅ Real Gemma model initialized (${backend == PreferredBackend.gpu ? "GPU" : "CPU"})');
      return true;

    } catch (e) {
      print('❌ Failed to initialize with ${backend.toString()}: $e');

      if (backend == PreferredBackend.gpu) {
        print('⚠️ GPU Init failed gracefully (Exception). Retrying with CPU...');
        _currentBackend = PreferredBackend.cpu;
        return _attemptLoad(modelPath: modelPath, backend: PreferredBackend.cpu);
      }

      _isModelLoaded = false;
      return false;
    }
  }

  Future<String?> _findModelFile() async {
    final possiblePaths = [
      '/storage/emulated/0/Download/gemma3-1B-it-int4.task',
      '/storage/emulated/0/Downloads/gemma3-1B-it-int4.task',
      '/storage/emulated/0/Documents/gemma3-1B-it-int4.task',
      '/storage/emulated/0/gemma3-1B-it-int4.task',
      '/storage/emulated/0/Download/gemma-3n-E2B-it-int4.task',
      '/storage/emulated/0/Downloads/gemma-3n-E2B-it-int4.task',
    ];

    for (String path in possiblePaths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final isReadable = await file.stat().then((stat) => stat.size > 0);
          if (isReadable) return path;
        } catch (e) { /* ignore */ }
      }
    }
    return null;
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isModelLoaded || _inferenceModel == null) throw Exception('Gemma model not initialized');
    return "Error: Use Stream implementation";
  }

  // UPDATED to accept imagePath and inject ML Kit context
  @override
  Stream<String> generateResponseStream(String prompt, {String? imagePath}) async* {
    if (!_isModelLoaded || _inferenceModel == null) throw Exception('Gemma model not initialized');

    try {
      final session = await _inferenceModel!.createSession(
        temperature: 0.7,
        randomSeed: 42,
        topK: 40,
      );

      // --- ML KIT VISION PROCESSING ---
      String imageContext = "";
      if (imagePath != null && imagePath.isNotEmpty) {
        print("🔍 Processing image with ML Kit before sending to Gemma...");
        imageContext = await _imageService.analyzeImageContext(imagePath);
        print("📸 Extracted Image Context: $imageContext");
      }

      final formattedPrompt = _formatPrompt(prompt, imageContext: imageContext);
      await session.addQueryChunk(Message.text(text: formattedPrompt, isUser: true));

      int garbageTokenCount = 0;

      await for (String token in session.getResponseAsync()) {
        final cleanToken = token.trim();

        if (cleanToken.contains('<unused')) {
          garbageTokenCount++;
          if (garbageTokenCount > 5) {
            yield "I'm having trouble processing that on this device.";
            break;
          }
          continue;
        }

        if (cleanToken.isNotEmpty &&
            !cleanToken.contains('<end_of_turn>') &&
            !cleanToken.contains('<start_of_turn>') &&
            !cleanToken.contains('model') &&
            !cleanToken.contains('user')) {
          yield token;
        }
      }
      await session.close();
    } catch (e) {
      print('❌ Error generating streaming response: $e');
      yield "I apologize, but I encountered an error.";
    }
  }

  // UPDATED: Dynamically injects image context into the prompt
  String _formatPrompt(String userInput, {String imageContext = ""}) {
    String finalInput = userInput;
    if (imageContext.isNotEmpty) {
      finalInput = "$imageContext\nUser's prompt regarding the image: $userInput";
    }

    return '''<start_of_turn>user
$finalInput

IMPORTANT: Keep your response short, concise, and to the point. Do not give long explanations. Limit to 1-2 sentences if possible.<end_of_turn>
<start_of_turn>model
''';
  }

  @override
  Future<void> disposeModel() async {
    try {
      if (_inferenceModel != null) {
        await _inferenceModel!.close();
        _inferenceModel = null;
        _isModelLoaded = false;
        print('🤖 Real Gemma model closed/disposed');
      }
    } catch (e) {
      print('❌ Error closing Gemma model: $e');
    }
  }
}