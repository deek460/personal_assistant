import 'package:flutter/material.dart';
import '../../core/models/ai_model.dart';

class AddModelDialog extends StatefulWidget {
  const AddModelDialog({Key? key}) : super(key: key);

  @override
  State<AddModelDialog> createState() => _AddModelDialogState();
}

class _AddModelDialogState extends State<AddModelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _generateDefaultName(String address) {
    // Extract filename from address
    final uri = Uri.tryParse(address);
    if (uri != null) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last.replaceAll('.task', '').replaceAll('.bin', '');
      }
    }
    return 'Custom Model';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Model'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Model Address *',
                hintText: 'Enter model path or URL',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a model address';
                }
                return null;
              },
              onChanged: (value) {
                if (_nameController.text.isEmpty ||
                    _nameController.text == _generateDefaultName(_addressController.text)) {
                  _nameController.text = _generateDefaultName(value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                hintText: 'Enter custom name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long press on dropdown items to delete them',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final model = AIModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text.trim().isEmpty
                    ? _generateDefaultName(_addressController.text.trim())
                    : _nameController.text.trim(),
                address: _addressController.text.trim(),
              );
              Navigator.of(context).pop(model);
            }
          },
          child: const Text('Add Model'),
        ),
      ],
    );
  }
}
