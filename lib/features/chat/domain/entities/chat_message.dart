import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String content;           // Current visible content in chat UI
  final String? rawContent;       // Raw model output (optional)
  final String? formattedContent; // Formatted text (optional)
  final bool isFromUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    this.rawContent,
    this.formattedContent,
    required this.isFromUser,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, content, rawContent, formattedContent, isFromUser, timestamp];

  ChatMessage copyWith({
    String? id,
    String? content,
    String? rawContent,
    String? formattedContent,
    bool? isFromUser,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      rawContent: rawContent ?? this.rawContent,
      formattedContent: formattedContent ?? this.formattedContent,
      isFromUser: isFromUser ?? this.isFromUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Optional: Add fromJson/toJson methods if serialization is used

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'rawContent': rawContent,
      'formattedContent': formattedContent,
      'isFromUser': isFromUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      rawContent: json['rawContent'] as String?,
      formattedContent: json['formattedContent'] as String?,
      isFromUser: json['isFromUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
