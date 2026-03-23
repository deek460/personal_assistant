abstract class GemmaRepository {
  Future<bool> initializeModel({String? modelPath});

  Future<String> generateResponse(String prompt);
  // NEW: Added imagePath parameter
  Stream<String> generateResponseStream(String prompt, {String? imagePath});

  Future<void> disposeModel();
  bool get isModelLoaded;
}