import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';

class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._internal();
  factory ImageProcessingService() => _instance;
  ImageProcessingService._internal();

  /// Processes an image and returns a text-based description of its contents
  Future<String> analyzeImageContext(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return "";

    final inputImage = InputImage.fromFile(file);

    // 1. Extract Text (OCR)
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    final extractedText = recognizedText.text.trim();
    await textRecognizer.close();

    // 2. Extract Object Labels
    final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.6);
    final imageLabeler = ImageLabeler(options: options);
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    final extractedLabels = labels.map((l) => l.label).join(', ');
    await imageLabeler.close();

    // 3. Format context for Gemma
    StringBuffer contextBuffer = StringBuffer();
    contextBuffer.writeln("[System: The user has attached an image to this message.]");

    if (extractedLabels.isNotEmpty) {
      contextBuffer.writeln("Objects/Concepts detected in the image: $extractedLabels.");
    }

    if (extractedText.isNotEmpty) {
      contextBuffer.writeln("Text found in the image: \"$extractedText\"");
    }

    if (extractedLabels.isEmpty && extractedText.isEmpty) {
      contextBuffer.writeln("No recognizable text or distinct objects were found in the image.");
    }

    return contextBuffer.toString();
  }
}