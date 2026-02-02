import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../logic/voice_cubit.dart';
import '../../data/models/voice_chat_message.dart';
import '../../../../features/gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../../features/gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../widgets/voice_message_bubble.dart';
import '../../../../shared/widgets/model_selector_dropdown.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({Key? key}) : super(key: key);

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final ModelManagementService _modelService = ModelManagementService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _debugInputController = TextEditingController();
  AIModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debugInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedModel() async {
    final model = await _modelService.getSelectedModel();
    setState(() => _selectedModel = model);
  }

  // --- SETTINGS DIALOG ---
  void _showSettingsDialog(BuildContext context) {
    // FIX: Capture the cubit instance HERE (from the parent context)
    // because the Dialog's context is detached from the Provider tree.
    final cubit = context.read<VoiceCubit>();

    showDialog(
      context: context,
      builder: (ctx) {
        // Use a local builder to refresh dialog content when lists change
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Use the captured 'cubit' instance directly
            final wakeWords = cubit.wakeWords;
            final voices = cubit.availableVoices;
            final currentVoice = cubit.currentVoice;

            // Find current voice object in list for dropdown
            // Maps in dart are not equal by reference, so we compare names
            Map<Object?, Object?>? selectedDropdownValue;
            if (currentVoice != null) {
              try {
                selectedDropdownValue = voices.firstWhere(
                        (v) => (v as Map)['name'] == currentVoice['name'],
                    orElse: () => null
                ) as Map<Object?, Object?>?;
              } catch (e) { /* ignore */ }
            }

            final TextEditingController wakeWordController = TextEditingController();

            return AlertDialog(
              title: const Text("Voice Settings"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Wake Words Section ---
                      const Text("Wake Words", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("Say any of these words to activate:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: wakeWords.map((word) {
                          return Chip(
                            label: Text(word),
                            onDeleted: wakeWords.length > 1 ? () async {
                              await cubit.removeWakeWord(word);
                              setDialogState(() {});
                            } : null, // Prevent deleting last wake word
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: wakeWordController,
                              decoration: const InputDecoration(
                                hintText: "Add new...",
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: () async {
                              if (wakeWordController.text.isNotEmpty) {
                                await cubit.addWakeWord(wakeWordController.text);
                                wakeWordController.clear();
                                setDialogState(() {});
                              }
                            },
                          )
                        ],
                      ),
                      const Divider(height: 32),

                      // --- Voice Selection Section ---
                      const Text("Assistant Voice", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (voices.isEmpty)
                        const Text("No system voices detected.", style: TextStyle(color: Colors.red))
                      else
                        DropdownButton<Map<Object?, Object?>>(
                          isExpanded: true,
                          value: selectedDropdownValue,
                          hint: const Text("Select Voice"),
                          items: voices.map((voice) {
                            final map = voice as Map;
                            return DropdownMenuItem<Map<Object?, Object?>>(
                              value: map,
                              child: Text(
                                "${map['name']} (${map['locale']})",
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newVoice) async {
                            if (newVoice != null) {
                              await cubit.updateVoice(Map<String,String>.from(newVoice));
                              setDialogState(() {});
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoiceCubit(
          SpeechToTextService(),
          TextToSpeechService(),
          GenerateResponseUseCase(GemmaRepositoryImpl())
      )..initializeServices(),
      child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: const Text("Voice Chat"),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRouter.home);
                    }
                  },
                ),
                actions: [
                  // SETTINGS BUTTON
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: () => _showSettingsDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear History',
                    onPressed: () {
                      context.read<VoiceCubit>().clearChatHistory();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.home),
                    tooltip: 'Home',
                    onPressed: () => context.go(AppRouter.home),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ModelSelectorDropdown(
                            selectedModel: _selectedModel,
                            onModelSelected: (model) {
                              setState(() => _selectedModel = model);
                              context.read<VoiceCubit>().switchModel(model);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Switching to: ${model.name}...')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(child: _VoiceChatBody(scrollController: _scrollController)),

                  // --- DEBUG INPUT FIELD ---
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Text("Debug:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('debug_input'),
                            controller: _debugInputController,
                            decoration: const InputDecoration(
                              hintText: "Inject Text Command",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('debug_send'),
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () {
                            if (_debugInputController.text.isNotEmpty) {
                              context.read<VoiceCubit>().processTextCommand(_debugInputController.text);
                              _debugInputController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

class _VoiceChatBody extends StatelessWidget {
  final ScrollController scrollController;

  const _VoiceChatBody({required this.scrollController});

  void _triggerScroll() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listener: (context, state) {
        if (state is SpeechUnavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition unavailable')),
          );
        }

        if (state is VoiceStreamingResponse ||
            state is VoiceResponseReady ||
            (state is VoiceListening && state.recognizedWords.isNotEmpty)) {
          _triggerScroll();
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            _buildStatusDisplay(context, state),
            const SizedBox(height: 16),
            Expanded(child: _buildChatHistory(context, state)),
            const SizedBox(height: 16),
            _buildControlButtons(context, state),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildStatusDisplay(BuildContext context, VoiceState state) {
    String status;
    Color statusColor;

    if (state is VoiceInitializing) {
      status = (state as VoiceInitializing).message;
      statusColor = Colors.orange;
    } else if (state is VoiceListening) {
      // Show first wake word or '...' if list is empty
      final words = context.read<VoiceCubit>().wakeWords;
      final displayWord = words.isNotEmpty ? '"${words.first}"' : 'Wake Word';
      status = 'Listening for $displayWord...';
      statusColor = Colors.red;
    } else if (state is VoiceProcessing) {
      status = 'Processing...';
      statusColor = Colors.orange;
    } else if (state is VoiceSpeaking || state is VoiceStreamingResponse) {
      status = 'Speaking...';
      statusColor = Colors.blue;
    } else if (state is SpeechReady) {
      final words = context.read<VoiceCubit>().wakeWords;
      final displayWord = words.isNotEmpty ? '"${words.first}"' : 'Wake Word';
      status = 'Ready. Say $displayWord to start.';
      statusColor = Colors.green;
    } else if (state is VoiceIdle) {
      status = 'Paused. Tap microphone to resume.';
      statusColor = Colors.grey;
    } else if (state is SpeechUnavailable) {
      status = 'Microphone Unavailable';
      statusColor = Colors.red;
    } else if (state is VoiceError) {
      status = (state as VoiceError).errorMessage;
      statusColor = Colors.red;
    } else {
      status = 'Initializing...';
      statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatHistory(BuildContext context, VoiceState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: state.chatHistory.isEmpty
                ? const Center(
              child: Text(
                'Say your wake word followed by your question!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.chatHistory.length,
              itemBuilder: (context, index) {
                final message = state.chatHistory[index];
                return VoiceMessageBubble(message: message);
              },
            ),
          ),
          if (state is VoiceListening && state.recognizedWords.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(100)),
              ),
              child: Text(
                'Hearing: ${state.recognizedWords}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, VoiceState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMicButton(context, state),
          if (state is VoiceSpeaking || state is VoiceStreamingResponse)
            _buildStopSpeakingButton(context),
          if (state is VoiceIdle || state is SpeechReady)
            _buildRestartButton(context),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context, VoiceState state) {
    bool isListening = state is VoiceListening;
    bool isProcessing = state is VoiceProcessing;
    bool canInteract = true;

    return GestureDetector(
      onTap: canInteract ? () {
        final cubit = context.read<VoiceCubit>();
        if (isListening) {
          cubit.stopListening();
        } else if (state is VoiceIdle || state is SpeechReady) {
          cubit.startListening();
        }
      } : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? Colors.red.withAlpha(38)
              : isProcessing
              ? Colors.orange.withAlpha(38)
              : Colors.blue.withAlpha(38),
          border: Border.all(
            color: isListening
                ? Colors.red
                : isProcessing
                ? Colors.orange
                : Colors.blue,
            width: 3,
          ),
        ),
        child: Icon(
          isListening
              ? Icons.stop
              : isProcessing
              ? Icons.sync
              : Icons.mic,
          size: 48,
          color: isListening
              ? Colors.red
              : isProcessing
              ? Colors.orange
              : Colors.blue,
        ),
      ),
    );
  }

  Widget _buildStopSpeakingButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<VoiceCubit>().stopSpeaking(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withAlpha(38),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Icon(Icons.volume_off, size: 32, color: Colors.red),
      ),
    );
  }

  Widget _buildRestartButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<VoiceCubit>().restartListening(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withAlpha(38),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: const Icon(Icons.refresh, size: 32, color: Colors.green),
      ),
    );
  }
}