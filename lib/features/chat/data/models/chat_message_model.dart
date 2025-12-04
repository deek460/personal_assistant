import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends Equatable {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
  });

  // Convert to domain entity
  ChatMessage toEntity() {
    return ChatMessage(
      id: id,
      content: content,
      isFromUser: isFromUser,
      timestamp: timestamp,
    );
  }

  // Create from domain entity
  factory ChatMessageModel.fromEntity(ChatMessage entity) {
    return ChatMessageModel(
      id: entity.id,
      content: entity.content,
      isFromUser: entity.isFromUser,
      timestamp: entity.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, content, isFromUser, timestamp];
}
