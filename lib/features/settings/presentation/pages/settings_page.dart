import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/settings_cubit.dart';
import '../../../../core/models/ai_model.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onSettingsChanged; // ✅ Injected callback
  const SettingsScreen({Key? key, this.onSettingsChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SettingsError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          } else if (state is SettingsLoaded) {
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildWakeWordSection(context, state),
                const Divider(height: 32),
                _buildVoiceSection(context, state),
                const Divider(height: 32),
                _buildModelSection(context, state),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildWakeWordSection(BuildContext context, SettingsLoaded state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mic, color: Colors.blue),
                SizedBox(width: 8),
                Text("Active Wake Word", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: state.availableWakeWords.contains(state.selectedWakeWord) ? state.selectedWakeWord : null,
                  hint: const Text("Select Wake Word"),
                  items: state.availableWakeWords.map((word) {
                    return DropdownMenuItem<String>(
                      value: word,
                      child: Text(word[0].toUpperCase() + word.substring(1)),
                    );
                  }).toList(),
                  onChanged: (newWord) {
                    if (newWord != null){
                      context.read<SettingsCubit>().setWakeWord(newWord).then((_) {
                        onSettingsChanged?.call(); // ✅ Fire and forget — no type dependency
                      });
                    };
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection(BuildContext context, SettingsLoaded state) {
    final List<Map<String, String>> typedVoices = [];
    for (var voice in state.voices) { // Fixed variable name
      if (voice is Map) typedVoices.add(Map<String, String>.from(voice));
    }

    Map<String, String>? matchingVoice;
    if (state.selectedVoice != null && state.selectedVoice!['name'] != null) { // Fixed variable name
      final targetName = state.selectedVoice!['name'];
      for (var v in typedVoices) {
        if (v['name'] == targetName) {
          matchingVoice = v;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assistant Voice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Map<String, String>>(
          value: matchingVoice,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'TTS Voice'),
          items: typedVoices.map((v) => DropdownMenuItem<Map<String, String>>(value: v, child: Text(v['name'] ?? 'Unknown Voice'))).toList(),
          onChanged: (val) {
            if (val != null) context.read<SettingsCubit>().setVoice(val); // Fixed method name
          },
        ),
      ],
    );
  }

  Widget _buildModelSection(BuildContext context, SettingsLoaded state) {
    AIModel? matchingModel;
    if (state.selectedModel != null) {
      try {
        matchingModel = state.models.firstWhere((m) => m.id == state.selectedModel!.id); // Fixed variable name
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Model (Gemma)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<AIModel>(
          value: matchingModel,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Active Model'),
          items: state.models.map((model) => DropdownMenuItem(value: model, child: Text(model.name))).toList(), // Fixed variable name
          onChanged: (val) {
            if (val != null) context.read<SettingsCubit>().setModel(val); // Fixed method name
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showAddModelDialog(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Import Custom .task Model'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }

  Future<void> _showAddModelDialog(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your model, then select the file.'),
            const SizedBox(height: 16),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Model Name', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()), child: const Text('Select File')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      cubit.pickAndAddCustomModel(name);
    } else if (name != null && name.isEmpty) {
      cubit.pickAndAddCustomModel("Imported Model");
    }
  }
}