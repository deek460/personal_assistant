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
  final TextEditingController _debugInputController = TextEditingController(); // For debug input
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

                  // --- DEBUG INPUT FIELD (Visible in Debug Mode or Testing) ---
                  // We use kDebugMode check, or you can use a custom flag.
                  // Since integration tests run in a mode that might be profile/release on Firebase,
                  // it's safer to always show it if a specific environment var is set,
                  // OR just leave it visible but small for now during development.
                  // For this request, I will make it visible.
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
                              // Inject text into the logic
                              // We need to access the private method _generateStreamingResponse ideally,
                              // or expose a public method for text input in VoiceCubit.
                              // Since _generateStreamingResponse is private, we will add a public wrapper in VoiceCubit.
                              // Assuming VoiceCubit has a method 'processTextCommand' (I will add it below).
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
      status = 'Listening for "Jack"...';
      statusColor = Colors.red;
    } else if (state is VoiceProcessing) {
      status = 'Processing...';
      statusColor = Colors.orange;
    } else if (state is VoiceSpeaking || state is VoiceStreamingResponse) {
      status = 'Speaking...';
      statusColor = Colors.blue;
    } else if (state is SpeechReady) {
      status = 'Ready. Say "Jack" to start.';
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
                'Say "Jack" followed by your question!',
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