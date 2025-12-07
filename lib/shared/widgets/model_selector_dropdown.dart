import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/voice/presentation/logic/voice_cubit.dart';
import '../../core/models/ai_model.dart';
import '../../core/services/model_management_service.dart';

class ModelSelectorDropdown extends StatefulWidget {
  final Function(AIModel) onModelSelected;
  final AIModel? selectedModel;

  const ModelSelectorDropdown({
    Key? key,
    required this.onModelSelected,
    this.selectedModel,
  }) : super(key: key);

  @override
  State<ModelSelectorDropdown> createState() => _ModelSelectorDropdownState();
}

class _ModelSelectorDropdownState extends State<ModelSelectorDropdown> {
  final ModelManagementService _modelService = ModelManagementService();
  List<AIModel> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void didUpdateWidget(ModelSelectorDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedModel != oldWidget.selectedModel) {
      _loadModels();
    }
  }

  Future<void> _loadModels() async {
    if (_models.isEmpty) setState(() => _isLoading = true);

    final models = await _modelService.getModels();

    // SAFETY FIX: De-duplicate list in case storage has bad data
    final uniqueModels = <String, AIModel>{};
    for (var model in models) {
      uniqueModels[model.id] = model;
    }

    if (mounted) {
      setState(() {
        _models = uniqueModels.values.toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAddModel() async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your model, then select the file.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Select File'),
          ),
        ],
      ),
    );

    if (name == null) return;

    if (mounted) {
      final cubit = context.read<VoiceCubit>();
      final newModel = await cubit.pickAndAddModel(customName: name.isEmpty ? null : name);

      if (newModel != null) {
        await _loadModels();
        widget.onModelSelected(newModel);
        cubit.switchModel(newModel);
      }
    }
  }

  Future<void> _showDeleteConfirmation(AIModel model) async {
    if (model.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default model')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete "${model.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _modelService.deleteModel(model.id);
      await _loadModels();

      if (widget.selectedModel?.id == model.id) {
        final defaultModel = _models.where((m) => m.isDefault).firstOrNull;
        if (defaultModel != null) {
          widget.onModelSelected(defaultModel);
          if (mounted) {
            context.read<VoiceCubit>().switchModel(defaultModel);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Ensure currently selected model is valid for the dropdown
    String? dropdownValue = widget.selectedModel?.id;
    if (_models.isEmpty || !_models.any((m) => m.id == dropdownValue)) {
      dropdownValue = null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: dropdownValue,
          isExpanded: true,
          hint: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Select Model'),
          ),
          items: [
            ..._models.map((model) => DropdownMenuItem<String>(
              value: model.id,
              child: GestureDetector(
                onLongPress: () => _showDeleteConfirmation(model),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (!model.isDefault)
                              Text(
                                model.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (model.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )),
            const DropdownMenuItem<String>(
              value: 'ADD_NEW_MODEL',
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Add New Model...',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == 'ADD_NEW_MODEL') {
              await _handleAddModel();
            } else if (value != null) {
              final selectedModel = _models.firstWhere((m) => m.id == value);
              await _modelService.setSelectedModelId(value);
              widget.onModelSelected(selectedModel);
            }
          },
        ),
      ),
    );
  }
}