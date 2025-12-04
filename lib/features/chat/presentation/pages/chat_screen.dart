import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/string_constants.dart';
import '../../../../core/models/ai_model.dart';
import '../../../../core/services/model_management_service.dart';
import '../../../../shared/widgets/model_selector_dropdown.dart';
import '../logic/chat_cubit.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/typing_indicator.dart';
import '../../../../core/navigation/app_router.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final ModelManagementService _modelService = ModelManagementService();
  AIModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadSelectedModel();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedModel() async {
    final model = await _modelService.getSelectedModel();
    setState(() => _selectedModel = model);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _onModelSelected(AIModel model) {
    setState(() => _selectedModel = model);

    // Notify the chat cubit about the model change
    context.read<ChatCubit>().updateSelectedModel(model);

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${model.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringConstants.chatTitle),
        actions: [
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              context.read<ChatCubit>().clearChat();
            },
            tooltip: 'Clear Chat',
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Chat',
            onPressed: () => context.go(AppRouter.voiceChat),
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
          // Model Selection Dropdown
          Container(
            color: Colors.grey.shade50,
            child: ModelSelectorDropdown(
              selectedModel: _selectedModel,
              onModelSelected: _onModelSelected,
            ),
          ),

          // Divider between dropdown and chat
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),

          // Messages List
          Expanded(
            child: BlocConsumer<ChatCubit, ChatState>(
              listener: (context, state) {
                if (state is ChatLoaded || state is ChatLoading) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                final messages = _getMessagesFromState(state);
                final isLoading = state is ChatLoading;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a conversation!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Type a message below to begin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        if (_selectedModel != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.smart_toy,
                                  size: 16,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Using: ${_selectedModel!.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && isLoading) {
                      return const TypingIndicator();
                    }

                    return MessageBubble(message: messages[index]);
                  },
                );
              },
            ),
          ),

          // Input Field
          BlocBuilder<ChatCubit, ChatState>(
            builder: (context, state) {
              return MessageInputField(
                onSendMessage: (message) {
                  context.read<ChatCubit>().sendMessage(message);
                },
                isLoading: state is ChatLoading,
              );
            },
          ),
        ],
      ),

      // Floating Action Button for Voice Input
      floatingActionButton: FloatingActionButton(
        tooltip: 'Voice Input',
        onPressed: () => context.go(AppRouter.voiceChat),
        child: const Icon(Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List _getMessagesFromState(ChatState state) {
    if (state is ChatInitial) return state.messages;
    if (state is ChatLoading) return state.messages;
    if (state is ChatLoaded) return state.messages;
    if (state is ChatError) return state.messages;
    return [];
  }
}
