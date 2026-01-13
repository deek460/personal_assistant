import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../domain/repositories/gemma_repository.dart';
import '../../../../core/services/text_formatter_service.dart';

class GemmaRepositoryImpl implements GemmaRepository {
  InferenceModel? _inferenceModel;
  bool _isModelLoaded = false;

  PreferredBackend _currentBackend = PreferredBackend.gpu;
  static const String _crashMarkerKey = 'gpu_init_crash_marker';

  // REPLACE THIS WITH YOUR ACTUAL DIRECT DOWNLOAD LINK
  static const String _modelDownloadUrl = 'https://drive.google.com/uc?export=download&id=1MXmjyrgLfl4tzohzyhstYe_7ZCuCTUHb';
  // Note: The above is a placeholder. You MUST use a link to your specific .task file.

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
        finalPath = await _prepareModelFile();
      }

      if (finalPath == null) {
        print('❌ Model file could not be prepared (Download failed?).');
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

  // UPDATED: Downloads model if missing
  Future<String?> _prepareModelFile() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      // Filename
      const fileName = 'gemma_model.task';
      final File destFile = File('${docsDir.path}/$fileName');

      if (await destFile.exists()) {
        print('✅ Model found locally at: ${destFile.path}');
        return destFile.path;
      }

      print('⬇️ Model not found. Starting download from $_modelDownloadUrl...');

      final request = await HttpClient().getUrl(Uri.parse(_modelDownloadUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final IOSink sink = destFile.openWrite();
        await response.pipe(sink);
        await sink.close();
        print('✅ Download complete: ${destFile.path}');
        return destFile.path;
      } else {
        print('❌ Download failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error preparing model file: $e');
      return null;
    }
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isModelLoaded || _inferenceModel == null) throw Exception('Gemma model not initialized');
    return "Error: Use Stream implementation";
  }

  @override
  Stream<String> generateResponseStream(String prompt) async* {
    if (!_isModelLoaded || _inferenceModel == null) throw Exception('Gemma model not initialized');

    try {
      final session = await _inferenceModel!.createSession(
        temperature: 0.7,
        randomSeed: 42,
        topK: 40,
      );

      final formattedPrompt = _formatPrompt(prompt);
      await session.addQueryChunk(Message.text(text: formattedPrompt, isUser: true));

      await for (String token in session.getResponseAsync()) {
        final cleanToken = token.trim();
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

  String _formatPrompt(String userInput) {
    return '''<start_of_turn>user
$userInput

IMPORTANT: Keep your response short, concise, and to the point. Do not give long explanations. Limit to 1-2 sentences if possible.<end_of_turn>
<start_of_turn>model
''';
  }

  @override
  Future<void> disposeModel() async {
    if (_inferenceModel != null) {
      await _inferenceModel!.close();
      _inferenceModel = null;
      _isModelLoaded = false;
    }
  }
}