import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';

class ModelManagementService {
  static const String _modelsKey = 'ai_models';
  static const String _selectedModelKey = 'selected_model_id';
  static const String _wakeWordsKey = 'wake_words';
  static const String _selectedWakeWordKey = 'selected_wake_word';
  static const String _voiceKey = 'selected_voice_preferences';

  static final ModelManagementService _instance = ModelManagementService._internal();
  factory ModelManagementService() => _instance;
  ModelManagementService._internal();

  // --- AI Model Management ---

  Future<List<AIModel>> getModels() async {
    final prefs = await SharedPreferences.getInstance();
    final modelsJson = prefs.getString(_modelsKey);

    if (modelsJson == null) {
      // Return default Gemma model
      final defaultModel = AIModel(
        id: 'gemma-default',
        name: 'Gemma 3n-E2B (Default)',
        address: 'local://gemma-3n-E2B-it-int4.task',
        isDefault: true,
      );
      await saveModels([defaultModel]);
      return [defaultModel];
    }

    final List<dynamic> modelsList = json.decode(modelsJson);
    return modelsList.map((json) => AIModel.fromJson(json)).toList();
  }

  Future<void> saveModels(List<AIModel> models) async {
    final prefs = await SharedPreferences.getInstance();
    final modelsJson = json.encode(models.map((model) => model.toJson()).toList());
    await prefs.setString(_modelsKey, modelsJson);
  }

  /// Adds a new model or updates an existing one if the ID matches.
  Future<void> addModel(AIModel model) async {
    final models = await getModels();

    final index = models.indexWhere((m) => m.id == model.id);

    if (index != -1) {
      models[index] = model;
    } else {
      models.add(model);
    }

    await saveModels(models);
  }

  Future<void> deleteModel(String modelId) async {
    final models = await getModels();
    models.removeWhere((model) => model.id == modelId);
    await saveModels(models);
  }

  Future<String?> getSelectedModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey);
  }

  Future<void> setSelectedModelId(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelId);
  }

  Future<AIModel?> getSelectedModel() async {
    final selectedId = await getSelectedModelId();
    if (selectedId == null) return null;

    final models = await getModels();
    return models.where((model) => model.id == selectedId).firstOrNull;
  }

  // --- Wake Word Management ---

  Future<List<String>> getWakeWords() async {
    final prefs = await SharedPreferences.getInstance();
    final words = prefs.getStringList(_wakeWordsKey);
    // Return default set if nothing saved
    return words ?? ['jack', 'computer', 'assistant'];
  }

  Future<void> saveWakeWords(List<String> words) async {
    final prefs = await SharedPreferences.getInstance();
    // Ensure we save lower case for consistent matching
    await prefs.setStringList(_wakeWordsKey, words.map((e) => e.toLowerCase()).toList());
  }

  Future<String> getSelectedWakeWord() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedWakeWordKey) ?? 'jack';
  }

  Future<void> saveSelectedWakeWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedWakeWordKey, word.toLowerCase());
  }

  // --- TTS Voice Management ---

  Future<Map<String, String>?> getSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_voiceKey);
    if (jsonStr == null) return null;
    try {
      return Map<String, String>.from(json.decode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSelectedVoice(Map<String, String> voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceKey, json.encode(voice));
  }
}