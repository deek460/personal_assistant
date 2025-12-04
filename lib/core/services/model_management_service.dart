import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';

class ModelManagementService {
  static const String _modelsKey = 'ai_models';
  static const String _selectedModelKey = 'selected_model_id';

  static final ModelManagementService _instance = ModelManagementService._internal();
  factory ModelManagementService() => _instance;
  ModelManagementService._internal();

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

  Future<void> addModel(AIModel model) async {
    final models = await getModels();
    models.add(model);
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
}
