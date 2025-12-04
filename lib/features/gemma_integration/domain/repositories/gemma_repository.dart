abstract class GemmaRepository {
  Future<bool> initializeModel();
  Future<String> generateResponse(String prompt);
  Stream<String> generateResponseStream(String prompt); // ADD this line
  Future<void> disposeModel();
  bool get isModelLoaded;
}
