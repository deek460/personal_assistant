import '../repositories/gemma_repository.dart';

class GenerateResponseUseCase {
  final GemmaRepository repository;

  GenerateResponseUseCase(this.repository);

  Future<String> call(String prompt) async {
    return await repository.generateResponse(prompt);
  }

  // UPDATED to accept imagePath
  Stream<String> callStreaming(String prompt, {String? imagePath}) async* {
    yield* repository.generateResponseStream(prompt, imagePath: imagePath);
  }
}