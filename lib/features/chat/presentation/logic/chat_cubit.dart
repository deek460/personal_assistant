import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';
import '../../../../core/services/text_formatter_service.dart';
import '../../../../core/constants/debug_constants.dart';
import '../../../../core/models/ai_model.dart';

// States
abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {
  final List<ChatMessage> messages;

  const ChatInitial({this.messages = const []});

  @override
  List<Object> get props => [messages];
}

class ChatLoading extends ChatState {
  final List<ChatMessage> messages;

  const ChatLoading({required this.messages});

  @override
  List<Object> get props => [messages];
}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;

  const ChatLoaded({required this.messages});

  @override
  List<Object> get props => [messages];
}

class ChatError extends ChatState {
  final String message;
  final List<ChatMessage> messages;

  const ChatError({
    required this.message,
    required this.messages,
  });

  @override
  List<Object> get props => [message, messages];
}

// Cubit
class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatInitial());

  final List<ChatMessage> _messages = [];

  AIModel? _selectedModel;

  // Call this when the user changes the dropdown
  void updateSelectedModel(AIModel model) {
    _selectedModel = model;
    // You might want to clear messages or notify listeners about model switch
    // Optionally emit a new state if you need UI feedback immediately
    // emit(ChatLoaded(messages: List.from(_messages)));
  }

  void sendMessage(String content) async {
    if (content
        .trim()
        .isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(),
      content: content.trim(),
      isFromUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    emit(ChatLoading(messages: List.from(_messages)));

    await Future.delayed(const Duration(seconds: 1));

    // The response message and formatting logic
    // Now includes optional model name for visibility
    String rawResponse = _generateSimpleResponse(content);

    if (_selectedModel != null && !_selectedModel!.isDefault) {
      rawResponse = '[${_selectedModel!.name}] $rawResponse';
    }

    final formattedResponse = TextFormatterService().formatAIResponse(
        rawResponse);

    final aiResponse = ChatMessage(
      id: DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(),
      content: kShowRawModelOutput ? rawResponse : formattedResponse,
      rawContent: rawResponse,
      formattedContent: formattedResponse,
      isFromUser: false,
      timestamp: DateTime.now(),
    );

    _messages.add(aiResponse);
    emit(ChatLoaded(messages: List.from(_messages)));
  }

  String _generateSimpleResponse(String userMessage) {
    final responses = [
      "I understand you said: \"$userMessage\". This is a basic response for now!",
      "Thanks for your message! The AI integration will be added in Phase 2.",
      "I heard: \"$userMessage\". Looking forward to helping you more once Gemma is integrated!",
      "Your message was: \"$userMessage\". Stay tuned for smarter responses!",
    ];

    return responses[DateTime
        .now()
        .second % responses.length];
  }

  void clearChat() {
    _messages.clear();
    emit(const ChatInitial());
  }

  void addAIResponse(String rawResponse) {
    final formattedResponse = TextFormatterService().formatAIResponse(
        rawResponse);
    final contentToShow = kShowRawModelOutput ? rawResponse : formattedResponse;

    final chatMessage = ChatMessage(
      id: DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(),
      content: contentToShow,
      rawContent: rawResponse,
      formattedContent: formattedResponse,
      isFromUser: false,
      timestamp: DateTime.now(),
    );

    _messages.add(chatMessage);
    emit(ChatLoaded(messages: List.from(_messages)));
  }
}