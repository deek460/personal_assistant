import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/settings_cubit.dart';
import '../../../../shared/widgets/model_selector_dropdown.dart';

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
                _buildListeningModeSection(context, state),
                const Divider(height: 32),
                if (state.listeningMode == 'wakeWord')
                  _buildWakeWordSection(context, state),
                if (state.listeningMode == 'wakeWord')
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // ✅ Reuse the existing widget — handles file picking, naming, saving, deleting
        ModelSelectorDropdown(
          selectedModel:   state.selectedModel,
          onModelSelected: (model) => context.read<SettingsCubit>().setModel(model),
        ),
      ],
    );
  }

  Widget _buildListeningModeSection(BuildContext context, SettingsLoaded state) {
    final isVad = state.listeningMode == 'vad';
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
                Icon(Icons.hearing, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Activation Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how the assistant activates.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'wakeWord',
                  label: Text('Wake Word'),
                  icon: Icon(Icons.record_voice_over),
                ),
                ButtonSegment(
                  value: 'vad',
                  label: Text('Voice Activity'),
                  icon: Icon(Icons.graphic_eq),
                ),
              ],
              selected: {state.listeningMode},
              onSelectionChanged: (selection) {
                context
                    .read<SettingsCubit>()
                    .setListeningMode(selection.first)
                    .then((_) => onSettingsChanged?.call());
              },
            ),
            const SizedBox(height: 8),
            Text(
              isVad
                  ? '🎙️ VAD mode: assistant activates the moment you start speaking.'
                  : '🔑 Wake word mode: say the wake word to activate the assistant.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}