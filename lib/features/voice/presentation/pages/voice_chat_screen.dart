import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../../../core/services/wake_word_service.dart'; // NEW IMPORT
import '../logic/voice_cubit.dart';
import '../../data/models/voice_chat_message.dart';
import '../../../../features/gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../../features/gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../widgets/voice_message_bubble.dart';
import '../../../../shared/widgets/model_selector_dropdown.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import 'vqa_test_runner.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({Key? key}) : super(key: key);

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final ModelManagementService _modelService = ModelManagementService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _debugInputController = TextEditingController();

  final GemmaRepositoryImpl _gemmaRepository = GemmaRepositoryImpl();

  AIModel? _selectedModel;
  bool _isFullScreenVision = false;
  bool _isTesting = false;

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

  void _runAutomatedTests(BuildContext context) async {
    if (_isTesting) return;

    final cubit = context.read<VoiceCubit>();
    if (cubit.state is VoiceInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for model to initialize first!')));
      return;
    }

    setState(() => _isTesting = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Starting 200 Automated VQA Tests... check logs!')));

    try {
      final testRunner = VqaTestRunner(_gemmaRepository);
      final csvPath = await testRunner.runAutomatedTests('assets/vqa_test/dataset.json');

      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Tests Complete! ✅"),
              content: Text("Results saved to:\n\n$csvPath\n\nUse Android Studio Device Explorer to pull this CSV file."),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
            )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Tests failed: $e')));
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _showSettingsDialog(BuildContext parentContext) {
    // Keep your exact existing _showSettingsDialog implementation
    final cubit = parentContext.read<VoiceCubit>();
    showDialog(
      context: parentContext,
      builder: (dialogCtx) {
        return BlocProvider.value(
          value: cubit,
          child: StatefulBuilder(
            builder: (statefulCtx, setDialogState) {
              final wakeWords = cubit.wakeWords;
              final selectedWakeWord = cubit.selectedWakeWord;
              final voices = cubit.availableVoices;
              final currentVoice = cubit.currentVoice;

              Map<Object?, Object?>? selectedVoiceValue;
              if (currentVoice != null) {
                try {
                  selectedVoiceValue = voices.firstWhere(
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
                        const Text("Active Wake Word", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: wakeWords.contains(selectedWakeWord) ? selectedWakeWord : null,
                          hint: const Text("Select Wake Word"),
                          items: wakeWords.map((word) {
                            return DropdownMenuItem<String>(
                              value: word,
                              child: Text(
                                word[0].toUpperCase() + word.substring(1),
                              ),
                            );
                          }).toList(),
                          onChanged: (newWord) async {
                            if (newWord != null) {
                              await cubit.setSelectedWakeWord(newWord);
                              setDialogState(() {});
                            }
                          },
                        ),
                        // ... Rest of your settings dialog
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(statefulCtx).pop(),
                    child: const Text("Close"),
                  ),
                ],
              );
            },
          ),
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
          WakeWordService(), // INJECT VOSK WAKE WORD SERVICE
          GenerateResponseUseCase(_gemmaRepository)
      )..initializeServices(),
      child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: GestureDetector(
                  onLongPress: () => _runAutomatedTests(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Voice Chat"),
                      if (_isTesting) ...[
                        const SizedBox(width: 8),
                        const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      ]
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) context.pop(); else context.go(AppRouter.home);
                  },
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.settings), onPressed: () => _showSettingsDialog(context)),
                  IconButton(icon: const Icon(Icons.clear_all), onPressed: () => context.read<VoiceCubit>().clearChatHistory()),
                  IconButton(icon: const Icon(Icons.home), onPressed: () => context.go(AppRouter.home)),
                ],
              ),
              body: BlocConsumer<VoiceCubit, VoiceState>(
                  listenWhen: (previous, current) => previous.isLiveVisionEnabled != current.isLiveVisionEnabled,
                  listener: (context, state) {
                    if (!state.isLiveVisionEnabled && _isFullScreenVision) {
                      setState(() => _isFullScreenVision = false);
                    }
                  },
                  builder: (context, state) {
                    final isCameraReady = state.isLiveVisionEnabled && state.cameraController?.value.isInitialized == true;
                    final Color inputBgColor = _isFullScreenVision ? Colors.black87 : Colors.grey.shade100;
                    final Color iconColor = _isFullScreenVision ? Colors.white70 : Colors.blueGrey;
                    final Color hintColor = _isFullScreenVision ? Colors.white54 : Colors.black54;
                    final Color textColor = _isFullScreenVision ? Colors.white : Colors.black;

                    return Stack(
                      children: [
                        if (isCameraReady && _isFullScreenVision)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              child: Center(child: CameraPreview(state.cameraController!)),
                            ),
                          ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                Container(
                                  color: _isFullScreenVision ? Colors.black54 : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ModelSelectorDropdown(
                                      selectedModel: _selectedModel,
                                      onModelSelected: (model) {
                                        setState(() => _selectedModel = model);
                                        context.read<VoiceCubit>().switchModel(model);
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      _VoiceChatBody(scrollController: _scrollController, isFullScreen: _isFullScreenVision),
                                      if (isCameraReady && !_isFullScreenVision)
                                        Positioned(
                                          top: 16, right: 16, width: 100, height: 140,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: double.infinity, height: double.infinity,
                                                decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.green, width: 3),
                                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)]
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(9),
                                                  child: CameraPreview(state.cameraController!),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 4, right: 4,
                                                child: GestureDetector(
                                                  onTap: () => setState(() => _isFullScreenVision = true),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      if (isCameraReady && _isFullScreenVision)
                                        Positioned(
                                          top: 16, right: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                            onPressed: () => setState(() => _isFullScreenVision = false),
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                                Container(
                                  color: inputBgColor,
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (state.pendingImagePath != null)
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 8, left: 8),
                                              height: 70, width: 70,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue, width: 2),
                                                image: DecorationImage(image: FileImage(File(state.pendingImagePath!)), fit: BoxFit.cover),
                                              ),
                                            ),
                                            Positioned(
                                              top: -12, right: -12,
                                              child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => context.read<VoiceCubit>().clearPendingImage()),
                                            )
                                          ],
                                        ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(state.isLiveVisionEnabled ? Icons.visibility : Icons.visibility_off, color: state.isLiveVisionEnabled ? Colors.green : iconColor),
                                            onPressed: () => context.read<VoiceCubit>().toggleLiveVision(),
                                          ),
                                          IconButton(icon: Icon(Icons.camera_alt, color: iconColor), onPressed: () => context.read<VoiceCubit>().pickImage(ImageSource.camera)),
                                          IconButton(icon: Icon(Icons.photo_library, color: iconColor), onPressed: () => context.read<VoiceCubit>().pickImage(ImageSource.gallery)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: TextField(
                                              controller: _debugInputController,
                                              style: TextStyle(color: textColor),
                                              decoration: InputDecoration(
                                                hintText: "Type or ask about an image...",
                                                hintStyle: TextStyle(color: hintColor),
                                                border: const OutlineInputBorder(),
                                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor.withAlpha(100))),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.send, color: _isFullScreenVision ? Colors.blue.shade300 : Colors.blue),
                                            onPressed: () {
                                              if (_debugInputController.text.isNotEmpty) {
                                                context.read<VoiceCubit>().processTextCommand(_debugInputController.text);
                                                _debugInputController.clear();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
              ),
            );
          }
      ),
    );
  }
}

class _VoiceChatBody extends StatelessWidget {
  final ScrollController scrollController;
  final bool isFullScreen;

  const _VoiceChatBody({required this.scrollController, required this.isFullScreen});

  void _triggerScroll() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceCubit, VoiceState>(
      listener: (context, state) {
        if (state is SpeechUnavailable) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech recognition unavailable')));
        if (state is VoiceStreamingResponse || state is VoiceResponseReady || (state is VoiceListening && state.recognizedWords.isNotEmpty)) _triggerScroll();
      },
      builder: (context, state) {
        final cubit = context.read<VoiceCubit>();
        return Column(
          children: [
            _buildStatusDisplay(context, state, cubit.selectedWakeWord),
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

  Widget _buildStatusDisplay(BuildContext context, VoiceState state, String activeWakeWord) {
    String status;
    Color statusColor;

    final displayWord = activeWakeWord.isNotEmpty ? '"${activeWakeWord[0].toUpperCase()}${activeWakeWord.substring(1)}"' : 'Wake Word';

    if (state is VoiceInitializing) {
      status = (state as VoiceInitializing).message;
      statusColor = Colors.orange;
    } else if (state is VoiceWaitingForWakeWord) {
      status = 'Sentinel Active. Say $displayWord.';
      statusColor = Colors.purple; // Distinct color for Vosk Sentinel mode
    } else if (state is VoiceListening) {
      status = 'Listening to your command...';
      statusColor = Colors.red;
    } else if (state is VoiceProcessing) {
      status = 'Processing...';
      statusColor = Colors.orange;
    } else if (state is VoiceSpeaking || state is VoiceStreamingResponse) {
      status = 'Speaking...';
      statusColor = Colors.blue;
    } else if (state is SpeechReady) {
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
        color: statusColor.withAlpha(isFullScreen ? 200 : 38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(color: isFullScreen ? Colors.white : statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChatHistory(BuildContext context, VoiceState state) {
    if (isFullScreen) {
      VoiceChatMessage? lastUserMsg;
      VoiceChatMessage? lastAiMsg;

      bool showRecentMessages = state is VoiceProcessing || state is VoiceStreamingResponse || state is VoiceResponseReady || state is VoiceSpeaking;

      if (showRecentMessages && state.chatHistory.isNotEmpty) {
        final lastMsg = state.chatHistory.last;
        if (lastMsg.isUser) {
          lastUserMsg = lastMsg;
        } else {
          lastAiMsg = lastMsg;
          for (int i = state.chatHistory.length - 2; i >= 0; i--) {
            if (state.chatHistory[i].isUser) {
              lastUserMsg = state.chatHistory[i];
              break;
            }
          }
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (lastUserMsg != null) VoiceMessageBubble(message: lastUserMsg) else const SizedBox.shrink(),
            if (state is VoiceListening && state.recognizedWords.isNotEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(200), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withAlpha(100))),
                child: Text('Hearing: ${state.recognizedWords}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white)),
              )
            else if (lastAiMsg != null) VoiceMessageBubble(message: lastAiMsg) else const SizedBox.shrink(),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Expanded(
            child: state.chatHistory.isEmpty
                ? const Center(child: Text('Say your wake word followed by your question!', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)))
                : ListView.builder(
              controller: scrollController, padding: const EdgeInsets.all(16),
              itemCount: state.chatHistory.length,
              itemBuilder: (context, index) => VoiceMessageBubble(message: state.chatHistory[index]),
            ),
          ),
          if (state is VoiceListening && state.recognizedWords.isNotEmpty)
            Container(
              width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withAlpha(100))),
              child: Text('Hearing: ${state.recognizedWords}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
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
          if (state is VoiceSpeaking || state is VoiceStreamingResponse) _buildStopSpeakingButton(context),
          if (state is VoiceIdle || state is SpeechReady) _buildRestartButton(context),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context, VoiceState state) {
    bool isListening = state is VoiceListening; // Native STT is active
    bool isSentinel = state is VoiceWaitingForWakeWord; // Vosk is active
    bool isProcessing = state is VoiceProcessing;
    bool canInteract = true;

    return GestureDetector(
      onTap: canInteract ? () {
        final cubit = context.read<VoiceCubit>();
        if (isListening || isSentinel) {
          cubit.stopListening();
        } else if (state is VoiceIdle || state is SpeechReady) {
          // If manually tapped, jump straight to dictation (skip wake word)
          cubit.forceStartDictation();
        }
      } : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? Colors.red.withAlpha(isFullScreen ? 150 : 38)
              : isSentinel
              ? Colors.purple.withAlpha(isFullScreen ? 150 : 38)
              : isProcessing
              ? Colors.orange.withAlpha(isFullScreen ? 150 : 38)
              : Colors.blue.withAlpha(isFullScreen ? 150 : 38),
          border: Border.all(
            color: isListening ? Colors.red : isSentinel ? Colors.purple : isProcessing ? Colors.orange : Colors.blue,
            width: 3,
          ),
        ),
        child: Icon(
          isListening || isSentinel ? Icons.stop : isProcessing ? Icons.sync : Icons.mic,
          size: 48,
          color: isFullScreen ? Colors.white : (isListening ? Colors.red : isSentinel ? Colors.purple : isProcessing ? Colors.orange : Colors.blue),
        ),
      ),
    );
  }

  Widget _buildStopSpeakingButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<VoiceCubit>().stopSpeaking(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withAlpha(isFullScreen ? 150 : 38), border: Border.all(color: Colors.red, width: 2)),
        child: Icon(Icons.volume_off, size: 32, color: isFullScreen ? Colors.white : Colors.red),
      ),
    );
  }

  Widget _buildRestartButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<VoiceCubit>().startSentinelMode(), // Restarts the loop
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.withAlpha(isFullScreen ? 150 : 38), border: Border.all(color: Colors.green, width: 2)),
        child: Icon(Icons.refresh, size: 32, color: isFullScreen ? Colors.white : Colors.green),
      ),
    );
  }
}