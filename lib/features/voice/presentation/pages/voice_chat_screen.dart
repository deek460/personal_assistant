import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../../../core/services/wake_word_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../logic/voice_cubit.dart';
import '../../../../features/gemma_integration/data/repositories/gemma_repository_impl.dart';
import '../../../../features/gemma_integration/domain/usecases/generate_response_usecase.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/voice_status_badge.dart';
import '../widgets/mic_button.dart';
import '../widgets/voice_input_bar.dart';
import '../widgets/camera_pip_view.dart';
import '../../../../shared/widgets/model_selector_dropdown.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import '../../../../features/settings/presentation/pages/settings_page.dart';
import '../../../../features/settings/presentation/logic/settings_cubit.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({Key? key}) : super(key: key);

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final ModelManagementService _modelService   = ModelManagementService();
  final ScrollController       _scrollController = ScrollController();
  AIModel? _selectedModel;
  String   _activeWakeWord  = 'jarvis';
  bool     _isFullScreen    = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
    _loadWakeWord();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedModel() async {
    final model = await _modelService.getSelectedModel();
    if (mounted) setState(() => _selectedModel = model);
  }

  Future<void> _loadWakeWord() async {
    final word = await _modelService.getSelectedWakeWord();
    if (mounted) setState(() => _activeWakeWord = word);
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (ctx) => SettingsCubit(
            ModelManagementService(),
            TextToSpeechService(),
          )..loadSettings(),
          child: SettingsScreen(
            onSettingsChanged: () => context.read<VoiceCubit>().refreshSettings(),
          ),
        ),
      ),
    ).then((_) {
      _loadWakeWord();
      context.read<VoiceCubit>().refreshSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoiceCubit(
        SpeechToTextService(),
        TextToSpeechService(),
        WakeWordService(),
        GenerateResponseUseCase(GemmaRepositoryImpl()),
      )..initializeServices(),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _isFullScreen ? null : _buildAppBar(context),
          body: BlocConsumer<VoiceCubit, VoiceState>(
            listenWhen: (prev, curr) =>
            prev.isLiveVisionEnabled != curr.isLiveVisionEnabled,
            listener: (context, state) {
              if (!state.isLiveVisionEnabled && _isFullScreen) {
                setState(() => _isFullScreen = false);
              }
            },
            builder: (context, state) {
              final cameraReady = state.isLiveVisionEnabled &&
                  state.cameraController?.value.isInitialized == true;

              return Stack(
                children: [
                  // ── Fullscreen camera background ──────────────────────────
                  if (cameraReady && _isFullScreen)
                    CameraFullScreenOverlay(
                      controller: state.cameraController!,
                      onCollapse: () => setState(() => _isFullScreen = false),
                    ),

                  // ── Main content column ───────────────────────────────────
                  Column(
                    children: [
                      // Model selector bar
                      if (!_isFullScreen)
                        _ModelBar(
                          selectedModel:   _selectedModel,
                          onModelSelected: (model) async {
                            setState(() => _selectedModel = model);
                            final cubit = context.read<VoiceCubit>();
                            await cubit.stopListening();
                            await cubit.initializeServices(specificModel: model);
                          },
                        ),

                      // Body
                      Expanded(
                        child: Stack(
                          children: [
                            _VoiceChatBody(
                              scrollController: _scrollController,
                              activeWakeWord:   _activeWakeWord,
                              isFullScreen:     _isFullScreen,
                            ),

                            // PiP camera (non-fullscreen)
                            if (cameraReady && !_isFullScreen)
                              Positioned(
                                top: 12, right: 12,
                                child: CameraPipView(
                                  controller: state.cameraController!,
                                  onExpand: () => setState(() => _isFullScreen = true),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Input bar
                      VoiceInputBar(
                        state:              state,
                        isFullScreen:       _isFullScreen,
                        onToggleLiveVision: () => context.read<VoiceCubit>().toggleLiveVision(),
                        onSendText:         (t) => context.read<VoiceCubit>().processTextCommand(t),
                        onPickCamera:       () => context.read<VoiceCubit>().pickImage(ImageSource.camera),
                        onPickGallery:      () => context.read<VoiceCubit>().pickImage(ImageSource.gallery),
                        onClearImage:       () => context.read<VoiceCubit>().clearPendingImage(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Assistant'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.canPop() ? context.pop() : context.go(AppRouter.home),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: 'Clear history',
          onPressed: () => context.read<VoiceCubit>().clearChatHistory(),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Settings',
          onPressed: () => _openSettings(context),
        ),
        IconButton(
          icon: const Icon(Icons.home_rounded),
          tooltip: 'Home',
          onPressed: () => context.go(AppRouter.home),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Model selector bar ───────────────────────────────────────────────────────

class _ModelBar extends StatelessWidget {
  final AIModel? selectedModel;
  final ValueChanged<AIModel> onModelSelected;

  const _ModelBar({required this.selectedModel, required this.onModelSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: ModelSelectorDropdown(
        selectedModel:   selectedModel,
        onModelSelected: onModelSelected,
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _VoiceChatBody extends StatelessWidget {
  final ScrollController scrollController;
  final String activeWakeWord;
  final bool isFullScreen;

  const _VoiceChatBody({
    required this.scrollController,
    required this.activeWakeWord,
    required this.isFullScreen,
  });

  void _scrollToBottom() {
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
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            const SizedBox(height: 16),

            // Status badge
            VoiceStatusBadge(
              state:          state,
              activeWakeWord: activeWakeWord,
              dark:           isFullScreen,
            ),

            const SizedBox(height: 16),

            // Chat history
            Expanded(
              child: isFullScreen
                  ? _FullScreenHistory(state: state)
                  : _ScrollableHistory(
                state:            state,
                scrollController: scrollController,
              ),
            ),

            const SizedBox(height: 16),

            // Control buttons
            _ControlRow(state: state, isFullScreen: isFullScreen),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ── Chat history variants ────────────────────────────────────────────────────

class _ScrollableHistory extends StatelessWidget {
  final VoiceState state;
  final ScrollController scrollController;

  const _ScrollableHistory({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: state.chatHistory.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                controller:  scrollController,
                padding:     const EdgeInsets.all(16),
                itemCount:   state.chatHistory.length,
                itemBuilder: (_, i) => VoiceMessageBubble(message: state.chatHistory[i]),
              ),
            ),

            // Live transcription strip
            if (state is VoiceListening && (state as VoiceListening).recognizedWords.isNotEmpty)
              _TranscriptionStrip(text: (state as VoiceListening).recognizedWords),
          ],
        ),
      ),
    );
  }
}

class _FullScreenHistory extends StatelessWidget {
  final VoiceState state;
  const _FullScreenHistory({required this.state});

  @override
  Widget build(BuildContext context) {
    final bool active = state is VoiceProcessing ||
        state is VoiceStreamingResponse ||
        state is VoiceResponseReady ||
        state is VoiceSpeaking;

    if (!active && !(state is VoiceListening)) return const SizedBox.shrink();

    // Find last user + last AI message
    VoiceMessageBubble? userBubble;
    VoiceMessageBubble? aiBubble;

    if (state.chatHistory.isNotEmpty) {
      final last = state.chatHistory.last;
      if (last.isUser) {
        userBubble = VoiceMessageBubble(message: last);
      } else {
        aiBubble = VoiceMessageBubble(message: last);
        for (int i = state.chatHistory.length - 2; i >= 0; i--) {
          if (state.chatHistory[i].isUser) {
            userBubble = VoiceMessageBubble(message: state.chatHistory[i]);
            break;
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (userBubble != null) userBubble else const SizedBox.shrink(),
          if (state is VoiceListening && (state as VoiceListening).recognizedWords.isNotEmpty)
            _TranscriptionStrip(text: (state as VoiceListening).recognizedWords, dark: true)
          else if (aiBubble != null) aiBubble else const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spatial_audio_off_rounded, size: 40, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'Say your wake word to begin',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TranscriptionStrip extends StatelessWidget {
  final String text;
  final bool dark;
  const _TranscriptionStrip({required this.text, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:  dark
            ? AppColors.listening.withValues(alpha: 0.15)
            : AppColors.listening.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: AppColors.listening.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          const Icon(Icons.hearing_rounded, size: 14, color: AppColors.listening),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily:  'DM Sans',
                fontStyle:   FontStyle.italic,
                fontSize:    14,
                color:       dark ? Colors.white70 : AppColors.listening,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control buttons row ──────────────────────────────────────────────────────

class _ControlRow extends StatelessWidget {
  final VoiceState state;
  final bool isFullScreen;

  const _ControlRow({required this.state, required this.isFullScreen});

  MicButtonState get _micState {
    if (state is VoiceWaitingForWakeWord) return MicButtonState.sentinel;
    if (state is VoiceListening)          return MicButtonState.listening;
    if (state is VoiceProcessing)         return MicButtonState.processing;
    if (state is VoiceSpeaking || state is VoiceStreamingResponse) return MicButtonState.speaking;
    return MicButtonState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final cubit   = context.read<VoiceCubit>();
    final isBusy  = state is VoiceListening || state is VoiceWaitingForWakeWord;
    final isSpeaking = state is VoiceSpeaking || state is VoiceStreamingResponse;
    final isIdle  = state is VoiceIdle || state is SpeechReady;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Restart button (shown when idle/paused)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isIdle
              ? Padding(
            key: const ValueKey('restart'),
            padding: const EdgeInsets.only(right: 24),
            child: _CircleAction(
              icon:    Icons.refresh_rounded,
              color:   AppColors.success,
              tooltip: 'Resume sentinel',
              onTap:   () => cubit.startSentinelMode(),
            ),
          )
              : const SizedBox(key: ValueKey('restart_empty'), width: 64),
        ),

        // Main mic button
        MicButton(
          state: _micState,
          onTap: () {
            if (isBusy)      cubit.stopListening();
            else if (isIdle) cubit.startActiveDictation();
          },
        ),

        // Stop speaking button (shown when TTS is active)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isSpeaking
              ? Padding(
            key: const ValueKey('stop'),
            padding: const EdgeInsets.only(left: 24),
            child: _CircleAction(
              icon:    Icons.volume_off_rounded,
              color:   AppColors.error,
              tooltip: 'Stop speaking',
              onTap:   () => cubit.stopSpeaking(),
            ),
          )
              : const SizedBox(key: ValueKey('stop_empty'), width: 64),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width:  52,
          height: 52,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}