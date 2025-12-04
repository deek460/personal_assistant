import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/string_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../features/voice/presentation/widgets/mic_button.dart';
import '../../../../features/voice/presentation/logic/voice_cubit.dart';
import '../../../../core/services/speech_to_text_service.dart';
import '../../../../core/services/text_to_speech_service.dart';
import '../../../../features/gemma_integration/data/repositories/gemma_repository_impl.dart';  // ADD THIS
import '../../../../features/gemma_integration/domain/usecases/generate_response_usecase.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide VoiceCubit here with required services (inject or create)
    return BlocProvider(
      create: (_) => VoiceCubit(
        SpeechToTextService(),
        TextToSpeechService(),
        GenerateResponseUseCase(GemmaRepositoryImpl()), // ADD THIS THIRD PARAMETER
      ),
      child: const _HomeContent(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringConstants.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => context.go(AppRouter.chat),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: BlocBuilder<VoiceCubit, VoiceState>(
            builder: (context, state) {
              MicButtonState micState = MicButtonState.idle;
              String statusText = StringConstants.tapToSpeak;

              if (state is VoiceListening) {
                micState = MicButtonState.listening;
                statusText = StringConstants.listening;
              } else if (state is VoiceProcessing) {
                micState = MicButtonState.processing;
                statusText = 'Processing...';
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assistant,
                          size: 80,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        Text(
                          StringConstants.homeSubtitle,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MicButton(
                          state: micState,
                          onTap: () {
                            print("Mic button tapped"); // Debug print
                            GoRouter.of(context).go(AppRouter.voiceChat);
                          },
                          onLongPress: () => context.go(AppRouter.chat),
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickActionButton(
                          icon: Icons.chat,
                          label: StringConstants.chat,
                          onTap: () => context.go(AppRouter.chat),
                        ),
                        _QuickActionButton(
                          icon: Icons.settings,
                          label: StringConstants.settings,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Settings coming soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: AppConstants.smallPadding,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withAlpha(25),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: AppColors.primaryLight,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
