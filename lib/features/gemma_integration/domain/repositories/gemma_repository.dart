abstract class GemmaRepository {
  // Updated to accept a specific path
  Future<bool> initializeModel({String? modelPath});

  Future<String> generateResponse(String prompt);
  Stream<String> generateResponseStream(String prompt);
  Future<void> disposeModel();
  bool get isModelLoaded;
}