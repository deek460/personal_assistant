import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:record/record.dart';

class SpeechToTextService {
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<RecordState>? _recordSub;

  bool _isAvailable = false;
  bool _isListening = false;

  // Callbacks
  Function(String)? _onResult;
  Function()? _onSessionComplete;

  Future<bool> init() async {
    print('🎤 Requesting microphone permission...');
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('❌ Microphone permission denied: $status');
      return false;
    }

    try {
      print('📂 Copying Sherpa-Onnx model assets...');
      final modelDir = await _copyModelAssets();
      if (modelDir == null) {
        print('❌ Failed to copy model assets. Aborting init.');
        return false;
      }
      print('✅ Assets copied to: $modelDir');

      // Initialize bindings
      sherpa_onnx.initBindings();

      final tokensPath = '$modelDir/tokens.txt';
      final encoderPath = '$modelDir/encoder.int8.onnx';
      final decoderPath = '$modelDir/decoder.int8.onnx';
      final joinerPath = '$modelDir/joiner.int8.onnx';

      // Double check files exist
      if (!File(tokensPath).existsSync()) {
        print('❌ Critical Error: tokens.txt not found at $tokensPath');
        return false;
      }

      // CONFIGURATION
      final modelConfig = sherpa_onnx.OnlineModelConfig(
        transducer: sherpa_onnx.OnlineTransducerModelConfig(
          encoder: encoderPath,
          decoder: decoderPath,
          joiner: joinerPath,
        ),
        tokens: tokensPath,
        numThreads: 1,
        provider: 'cpu',
        debug: true, // Enable debug to see C++ logs
        modelType: 'zipformer',
      );

      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
      );

      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      _isAvailable = true;
      print('✅ Sherpa-Onnx Initialized Successfully');

    } catch (e) {
      print('❌ Failed to init Sherpa-Onnx: $e');
      _isAvailable = false;
    }

    return _isAvailable;
  }

  Future<String?> _copyModelAssets() async {
    try {
      // Use TemporaryDirectory instead of ApplicationDocumentsDirectory
      // This is often safer for passing paths to C++ libs
      final tempDir = await getTemporaryDirectory();
      final modelPath = '${tempDir.path}/sherpa_model';
      final dir = Directory(modelPath);

      if (await dir.exists()) {
        // Optional: Delete and recreate to ensure fresh assets during dev
        // await dir.delete(recursive: true);
        print('📂 Model directory exists: $modelPath');
        return modelPath;
      }

      await dir.create(recursive: true);

      // Matches your file structure: assets/stt/
      const assetPrefix = 'assets/stt';

      final files = [
        'tokens.txt',
        'encoder.int8.onnx',
        'decoder.int8.onnx',
        'joiner.int8.onnx',
      ];

      for (final f in files) {
        final fullAssetPath = '$assetPrefix/$f';
        print('   - Copying $fullAssetPath...');
        try {
          final data = await rootBundle.load(fullAssetPath);
          final bytes = data.buffer.asUint8List();
          await File('$modelPath/$f').writeAsBytes(bytes, flush: true);
        } catch (e) {
          print('❌ Failed to load asset: "$fullAssetPath". Check pubspec.yaml.');
          throw e;
        }
      }

      return modelPath;
    } catch (e) {
      print('❌ Error copying model assets: $e');
      return null;
    }
  }

  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required Function() onSessionComplete,
  }) async {
    if (!_isAvailable || _recognizer == null) {
      print('❌ Cannot start listening: Recognizer not available');
      return;
    }

    _onResult = onResult;
    _onSessionComplete = onSessionComplete;
    _isListening = true;

    try {
      _stream = _recognizer!.createStream();

      if (await _audioRecorder.hasPermission()) {
        const encoder = AudioEncoder.pcm16bits;
        const config = RecordConfig(
          encoder: encoder,
          sampleRate: 16000,
          numChannels: 1,
        );

        final stream = await _audioRecorder.startStream(config);

        stream.listen((data) {
          final samplesFloat32 = _convertBytesToFloat32(Uint8List.fromList(data));

          _stream!.acceptWaveform(
              samples: samplesFloat32,
              sampleRate: 16000
          );

          while (_recognizer!.isReady(_stream!)) {
            _recognizer!.decode(_stream!);
          }

          final result = _recognizer!.getResult(_stream!);
          if (result.text.isNotEmpty) {
            _onResult?.call(result.text);
          }

          if (_recognizer!.isEndpoint(_stream!)) {
            _recognizer!.reset(_stream!);
            if (result.text.isNotEmpty) {
              _onSessionComplete?.call();
            }
          }
        }, onDone: () {
          print('Audio stream stopped.');
        });

        print('🎤 Sherpa listening...');
      } else {
        print('❌ AudioRecorder permission check failed');
      }

    } catch (e) {
      print('❌ Error starting Sherpa: $e');
      _onSessionComplete?.call();
    }
  }

  Float32List _convertBytesToFloat32(Uint8List bytes) {
    final int16List = Int16List.view(bytes.buffer);
    final float32List = Float32List(int16List.length);
    for (var i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }
    return float32List;
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _audioRecorder.stop();
    _stream?.free();
    _stream = null;
    print('Stopped listening');
  }

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  void dispose() {
    _recordSub?.cancel();
    _audioRecorder.dispose();
    _stream?.free();
    _recognizer?.free();
  }
}