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
  Future<bool> initializeModel() async {
    try {
      print('🤖 Initializing real Gemma model...');

      final gemma = FlutterGemmaPlugin.instance;
      final modelManager = gemma.modelManager;

      final modelPath = await _findModelFile();
      if (modelPath == null) {
        print('❌ Model file not found in any location');
        return false;
      }

      print('📦 Using model directly at: $modelPath');

      print('🔗 Setting model path for direct access...');
      await modelManager.setModelPath(modelPath);

      print('✅ Model path set successfully');

      print(' Creating inference model...');
      _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu,
        maxTokens: 512,
      );

      _isModelLoaded = true;
      print('✅ Real Gemma model initialized directly from Downloads!');
      return true;
    } catch (e) {
      print('❌ Failed to initialize Gemma model with GPU: $e');
      print('💡 Trying CPU backend...');

      try {
        _inferenceModel = await FlutterGemmaPlugin.instance.createModel(
          modelType: ModelType.gemmaIt,
          preferredBackend: PreferredBackend.cpu,
          maxTokens: 256,
        );

        _isModelLoaded = true;
        print('✅ Gemma model initialized with CPU backend!');
        return true;
      } catch (e2) {
        print('❌ CPU fallback also failed: $e2');
        _isModelLoaded = false;
        return false;
      }
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
          final size = await file.length();
          print('✅ Found model: $path (${(size / 1024 / 1024).toStringAsFixed(1)} MB)');

          final isReadable = await file.stat().then((stat) => stat.size > 0);
          if (isReadable) return path;

          print('⚠️ File exists but not readable: $path');
        } catch (e) {
          print('⚠️ Error accessing file: $path - $e');
        }
      } else {
        print('❌ Not found: $path');
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
    } catch (_) {
      // best-effort logging
    }
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isModelLoaded || _inferenceModel == null) {
      throw Exception('Gemma model not initialized');
    }

    try {
      print('🤖 Generating real AI response for: $prompt');

      final session = await _inferenceModel!.createSession(
        temperature: 0.8,
        randomSeed: 42,
        topK: 40,
      );

      final formattedPrompt = _formatPrompt(prompt);
      await session.addQueryChunk(Message.text(text: formattedPrompt, isUser: true));

      final response = await session.getResponse();

      print('RAW_MODEL_RESPONSE >>>\n$response\n<<< RAW_MODEL_RESPONSE');
      await _appendToModelLog(response, contextHint: 'non_stream_final');

      await session.close();

      final formattedResponse = TextFormatterService().formatAIResponse(response);
      print('✅ Generated real AI response: $formattedResponse');

      return formattedResponse;
    } catch (e) {
      print('❌ Error generating response: $e');
      final fallbackResponse =
          'I apologize, but I encountered an error while processing your request. Please try again.';
      return TextFormatterService().formatAIResponse(fallbackResponse);
    }
  }

  @override
  Stream<String> generateResponseStream(String prompt) async* {
    if (!_isModelLoaded || _inferenceModel == null) {
      throw Exception('Gemma model not initialized');
    }

    try {
      print('🤖 Generating real streaming AI response for: $prompt');

      final session = await _inferenceModel!.createSession(
        temperature: 0.8,
        randomSeed: 42,
        topK: 40,
      );

      final formattedPrompt = _formatPrompt(prompt);
      await session.addQueryChunk(Message.text(text: formattedPrompt, isUser: true));

      StringBuffer rawBuffer = StringBuffer();

      await for (String token in session.getResponseAsync()) {
        rawBuffer.write(token);
        final cleanToken = token.trim();

        // Log each token
        print('RAW_TOKEN: "$token"');
        await _appendToModelLog(token, contextHint: 'stream_token');

        // FIXED: Only yield the cleaned token.
        // We do NOT yield accumulated chunks here to avoid duplication.
        if (cleanToken.isNotEmpty &&
            !cleanToken.contains('<end_of_turn>') &&
            !cleanToken.contains('<start_of_turn>') &&
            !cleanToken.contains('model') &&
            !cleanToken.contains('user')) {

          // We pass the raw token or slightly cleaned token directly.
          // The UI/Cubit will handle aggregation.
          yield token;
        }
      }

      // Log complete aggregated raw stream
      final rawAll = rawBuffer.toString();
      print('RAW_STREAM_AGGREGATED >>>\n$rawAll\n<<< RAW_STREAM_AGGREGATED');
      await _appendToModelLog(rawAll, contextHint: 'stream_aggregated_final');

      await session.close();
    } catch (e) {
      print('❌ Error generating streaming response: $e');
      final fallbackResponse =
          'I apologize, but I encountered an error while processing your request. Please try again.';
      yield TextFormatterService().formatAIResponse(fallbackResponse);
    }
  }

  String _formatPrompt(String userInput) {
    return '''<start_of_turn>user
$userInput<end_of_turn>
<start_of_turn>model
''';
  }

  String _cleanResponse(String rawResponse) {
    return TextFormatterService().formatAIResponse(rawResponse);
  }

  @override
  Future<void> disposeModel() async {
    try {
      if (_inferenceModel != null) {
        await _inferenceModel!.close();
        _inferenceModel = null;
        _isModelLoaded = false;
        print('🤖 Real Gemma model closed');
      }
    } catch (e) {
      print('❌ Error closing Gemma model: $e');
    }
  }
}