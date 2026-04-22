import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import 'package:file_picker/file_picker.dart';

// --- STATES ---
abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}
class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final List<AIModel> models;
  final AIModel? selectedModel;
  final List<dynamic> voices;
  final Map<String, String>? selectedVoice;

  // 🔴 Added Wake Word Properties
  final List<String> availableWakeWords;
  final String selectedWakeWord;

  const SettingsLoaded({
    required this.models,
    this.selectedModel,
    required this.voices,
    this.selectedVoice,
    required this.availableWakeWords,
    required this.selectedWakeWord,
  });

  SettingsLoaded copyWith({
    List<AIModel>? models,
    AIModel? selectedModel,
    List<dynamic>? voices,
    Map<String, String>? selectedVoice,
    List<String>? availableWakeWords,
    String? selectedWakeWord,
  }) {
    return SettingsLoaded(
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      voices: voices ?? this.voices,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableWakeWords: availableWakeWords ?? this.availableWakeWords,
      selectedWakeWord: selectedWakeWord ?? this.selectedWakeWord,
    );
  }

  @override
  List<Object?> get props => [
    models, selectedModel, voices, selectedVoice, availableWakeWords, selectedWakeWord
  ];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- CUBIT ---
class SettingsCubit extends Cubit<SettingsState> {
  final ModelManagementService _modelService;
  final TextToSpeechService _ttsService;

  SettingsCubit(this._modelService, this._ttsService) : super(SettingsInitial());

  Future<void> loadSettings() async {
    emit(SettingsLoading());
    try {
      final models = await _modelService.getModels();
      final selectedModel = await _modelService.getSelectedModel();
      final voices = await _ttsService.getAvailableVoices();
      final selectedVoice = await _modelService.getSelectedVoice();

      // 🔴 Fetch Wake Words
      final wakeWords = await _modelService.getWakeWords();
      final selectedWake = await _modelService.getSelectedWakeWord();

      emit(SettingsLoaded(
        models: models,
        selectedModel: selectedModel,
        voices: voices,
        selectedVoice: selectedVoice,
        availableWakeWords: wakeWords,
        selectedWakeWord: selectedWake,
      ));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  // 🔴 Added setWakeWord function
  Future<void> setWakeWord(String word) async {
    final currentState = state;
    if (currentState is SettingsLoaded) {
      await _modelService.saveSelectedWakeWord(word);
      emit(currentState.copyWith(selectedWakeWord: word));
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    final currentState = state;
    if (currentState is SettingsLoaded) {
      await _ttsService.setVoice(voice);
      await _modelService.saveSelectedVoice(voice);
      emit(currentState.copyWith(selectedVoice: voice));
    }
  }

  Future<void> setModel(AIModel model) async {
    final currentState = state;
    if (currentState is SettingsLoaded) {
      await _modelService.setSelectedModelId(model.id);
      emit(currentState.copyWith(selectedModel: model));
    }
  }

  Future<void> pickAndAddCustomModel(String customName) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any);
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        final newModel = AIModel(
          id: 'custom-${DateTime
              .now()
              .millisecondsSinceEpoch}',
          name: customName,
          address: path,
          isDefault: false,
          isGpuSupported: null,
        );
        await _modelService.addModel(newModel);

        // Reload settings to grab the updated list and select the new model
        await loadSettings();
        await setModel(newModel);
      }
    } catch (e) {
      emit(SettingsError("Failed to pick file: $e"));
    }
  }
}
