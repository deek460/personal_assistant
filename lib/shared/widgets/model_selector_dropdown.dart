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

    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
      });
    }
  }

  // New method to handle adding a model directly from dropdown
  Future<void> _handleAddModel() async {
    final nameController = TextEditingController();

    // 1. Show Dialog to get Name
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

    if (name == null) return; // User cancelled

    // 2. Trigger Cubit Browsing logic
    if (mounted) {
      // Use the builder context from the parent or ensure this context can access cubit
      // Since this widget is inside VoiceChatScreen which has the provider, this context should work
      // if BlocProvider is above VoiceChatScreen.
      // Wait, VoiceChatScreen wraps its body in BlocProvider.
      // This widget is a child of VoiceChatScreen's body. So context.read<VoiceCubit>() works.

      final cubit = context.read<VoiceCubit>();

      // Pass the name to the cubit's picking function
      final newModel = await cubit.pickAndAddModel(customName: name.isEmpty ? null : name);

      if (newModel != null) {
        // 3. Update local list immediately
        await _loadModels();

        // 4. Select the new model
        widget.onModelSelected(newModel);

        // 5. Trigger switch in cubit (pickAndAddModel adds it but we want to ensure UI sync)
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
          context.read<VoiceCubit>().switchModel(defaultModel);
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

    String? dropdownValue = widget.selectedModel?.id;
    if (_models.isNotEmpty && !_models.any((m) => m.id == dropdownValue)) {
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
          // Construct Items List
          items: [
            // 1. Existing Models
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
            // 2. Add Model Option
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