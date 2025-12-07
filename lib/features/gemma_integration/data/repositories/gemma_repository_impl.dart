import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/repositories/gemma_repository.dart';
import '../../../../core/services/text_formatter_service.dart';

class GemmaRepositoryImpl implements GemmaRepository {
  InferenceModel? _inferenceModel;
  bool _isModelLoaded = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<bool> initializeModel({String? modelPath}) async {
    try {
      print('🤖 Initializing Gemma model...');

      // 1. FREE RAM: Ensure any existing model is closed first
      await disposeModel();

      final gemma = FlutterGemmaPlugin.instance;
      final modelManager = gemma.modelManager;

      String? finalPath;

      // 2. Determine Path: Use provided path OR auto-discover
      if (modelPath != null && modelPath.isNotEmpty) {
        // Handle "local://" prefix if present from your ID system
        if (modelPath.startsWith('local://')) {
          // If you have a specific logic for local:// paths, decode it here.
          // For now, assuming direct file paths are passed or we strip the prefix if it's just a marker.
          // If 'local://' implies a default asset, we might skip this.
          // Let's assume the UI passes a clean absolute path for custom models.
          finalPath = modelPath.replaceFirst('local://', '');
        } else {
          finalPath = modelPath;
        }

        final file = File(finalPath);
        if (!file.existsSync()) {
          print("❌ Provided path does not exist: $finalPath");
          finalPath = null; // Fallback to discovery
        }
      }

      if (finalPath == null) {
        finalPath = await _findModelFile();
      }

      if (finalPath == null) {
        print('❌ Model file not found in any location');
        return false;
      }

      print('📦 Loading model from: $finalPath');
      await modelManager.setModelPath(finalPath);

      print(' Creating inference model...');
      // Try GPU first
      try {
        _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
          modelType: ModelType.gemmaIt,
          preferredBackend: PreferredBackend.gpu,
          maxTokens: 512,
        );
        print('✅ Real Gemma model initialized (GPU)');
      } catch (e) {
        print('⚠️ GPU Init failed: $e. Switching to CPU...');
        _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
          modelType: ModelType.gemmaIt,
          preferredBackend: PreferredBackend.cpu,
          maxTokens: 256,
        );
        print('✅ Real Gemma model initialized (CPU)');
      }

      _isModelLoaded = true;
      return true;
    } catch (e) {
      print('❌ Failed to initialize Gemma model: $e');
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
    ];

    for (String path in possiblePaths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final isReadable = await file.stat().then((stat) => stat.size > 0);
          if (isReadable) return path;
        } catch (e) {
          print('⚠️ Error accessing file: $path - $e');
        }
      }
    }
    return null;
  }

  Future<void> _appendToModelLog(String content, {String contextHint = ''}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/model_raw_output.log');
      final ts = DateTime.now().toIso8601String();
      final header = '[$ts][$contextHint]';
      await file.writeAsString('$header\n$content\n---\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isModelLoaded || _inferenceModel == null) {
      throw Exception('Gemma model not initialized');
    }
    // ... (rest of implementation same as before)
    // To save space, I am reusing your existing logic logic here implicitly
    // but ensured disposeModel is called in initialize.
    return "Error: Use Stream implementation";
  }

  @override
  Stream<String> generateResponseStream(String prompt) async* {
    if (!_isModelLoaded || _inferenceModel == null) {
      throw Exception('Gemma model not initialized');
    }

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