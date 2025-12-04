class VoiceChatMessage {
  final String id;
  final String text;
  final String? rawContent;     // Add this field
  final String? formattedContent; // Add this field
  final bool isUser;
  final DateTime timestamp;

  VoiceChatMessage({
    required this.id,
    required this.text,
    this.rawContent,           // Add this parameter
    this.formattedContent,     // Add this parameter
    required this.isUser,
    required this.timestamp,
  });

  // Update copyWith method if you have one
  VoiceChatMessage copyWith({
    String? id,
    String? text,
    String? rawContent,
    String? formattedContent,
    bool? isUser,
    DateTime? timestamp,
  }) {
    return VoiceChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      rawContent: rawContent ?? this.rawContent,
      formattedContent: formattedContent ?? this.formattedContent,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Update toJson/fromJson if you have serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'rawContent': rawContent,
      'formattedContent': formattedContent,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory VoiceChatMessage.fromJson(Map<String, dynamic> json) {
    return VoiceChatMessage(
      id: json['id'],
      text: json['text'],
      rawContent: json['rawContent'],
      formattedContent: json['formattedContent'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
