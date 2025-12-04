import '../repositories/gemma_repository.dart';

class GenerateResponseUseCase {
  final GemmaRepository repository;

  GenerateResponseUseCase(this.repository);

  Future<String> call(String prompt) async {
    return await repository.generateResponse(prompt);
  }

  // ADD this new streaming method
  Stream<String> callStreaming(String prompt) async* {
    yield* repository.generateResponseStream(prompt);
  }
}
