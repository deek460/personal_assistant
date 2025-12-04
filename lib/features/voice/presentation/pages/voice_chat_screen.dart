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
  AIModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Voice Chat"),
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
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Text Chat',
              onPressed: () => context.go(AppRouter.chat),
            ),
          ],
        ),
        body: Column(
          children: [
            // Model Selection Dropdown
            ModelSelectorDropdown(
              selectedModel: _selectedModel,
              onModelSelected: (model) {
                setState(() => _selectedModel = model);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: ${model.name}')),
                );
              },
            ),
            // Rest of your existing body content
            const Expanded(child: _VoiceChatBody()),
          ],
        ),
      ),
    );
  }
}

class _VoiceChatBody extends StatelessWidget {
  const _VoiceChatBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listener: (context, state) {
        if (state is SpeechUnavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition unavailable')),
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            // Status display
            _buildStatusDisplay(context, state),

            const SizedBox(height: 16),

            // Chat history (scrollable)
            Expanded(
              child: _buildChatHistory(context, state),
            ),

            const SizedBox(height: 16),

            // Control buttons
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

    if (state is VoiceListening) {
      status = 'Listening...';
      statusColor = Colors.red;
    } else if (state is VoiceProcessing) {
      status = 'Processing...';
      statusColor = Colors.orange;
    } else if (state is VoiceResponseReady) {
      status = 'Response Ready';
      statusColor = Colors.green;
    } else if (state is VoiceSpeaking) {
      status = 'Speaking...';
      statusColor = Colors.blue;
    } else if (state is SpeechReady) {
      // FIXED: Added explicit handling for SpeechReady state
      status = 'Model Loaded. Tap to Speak.';
      statusColor = Colors.green;
    } else if (state is VoiceIdle) {
      status = 'Tap microphone to speak';
      statusColor = Colors.grey;
    } else if (state is SpeechUnavailable) {
      status = 'Microphone Unavailable';
      statusColor = Colors.red;
    } else if (state is VoiceError) {
      status = 'Error initializing';
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
          // Chat messages
          Expanded(
            child: state.chatHistory.isEmpty
                ? const Center(
              child: Text(
                'Start talking to begin the conversation!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.chatHistory.length,
              itemBuilder: (context, index) {
                final message = state.chatHistory[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Current listening/processing display
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
                'You\'re saying: ${state.recognizedWords}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(VoiceChatMessage message) {
    return VoiceMessageBubble(message: message);
  }

  Widget _buildControlButtons(BuildContext context, VoiceState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone button
          _buildMicButton(context, state),

          // Stop speaking button (only show when speaking)
          if (state is VoiceSpeaking)
            _buildStopSpeakingButton(context),

          // Restart button (only show when idle or ready)
          if (state is VoiceIdle || state is SpeechReady)
            _buildRestartButton(context),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context, VoiceState state) {
    bool isListening = state is VoiceListening;
    bool isProcessing = state is VoiceProcessing;
    bool canInteract = isListening || (state is VoiceIdle || state is SpeechReady);

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
              : (state is SpeechReady ? Colors.green.withAlpha(38) : Colors.blue.withAlpha(38)), // Visual hint for ready
          border: Border.all(
            color: isListening
                ? Colors.red
                : isProcessing
                ? Colors.orange
                : (state is SpeechReady ? Colors.green : Colors.blue),
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
              : (state is SpeechReady ? Colors.green : Colors.blue),
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