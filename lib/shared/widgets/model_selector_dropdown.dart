import 'package:flutter/material.dart';
import '../../core/models/ai_model.dart';
import '../../core/services/model_management_service.dart';
import 'add_model_dialog.dart';

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

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await _modelService.getModels();
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  Future<void> _showAddModelDialog() async {
    final result = await showDialog<AIModel>(
      context: context,
      builder: (context) => const AddModelDialog(),
    );

    if (result != null) {
      await _modelService.addModel(result);
      await _loadModels();
      widget.onModelSelected(result);
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

      // If deleted model was selected, select default
      if (widget.selectedModel?.id == model.id) {
        final defaultModel = _models.where((m) => m.isDefault).firstOrNull;
        if (defaultModel != null) {
          widget.onModelSelected(defaultModel);
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.selectedModel?.id,
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
            DropdownMenuItem<String>(
              value: 'add_model',
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Add Model',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == 'add_model') {
              await _showAddModelDialog();
            } else if (value != null) {
              final selectedModel = _models.where((m) => m.id == value).first;
              await _modelService.setSelectedModelId(value);
              widget.onModelSelected(selectedModel);
            }
          },
        ),
      ),
    );
  }
}
