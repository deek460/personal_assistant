class VoiceChatMessage {
  final String id;
  final String text;
  final String? rawContent;
  final String? formattedContent;
  final bool isUser;
  final DateTime timestamp;
  final Duration? latency;
  final String? imagePath; // NEW: Path to local image file

  VoiceChatMessage({
    required this.id,
    required this.text,
    this.rawContent,
    this.formattedContent,
    required this.isUser,
    required this.timestamp,
    this.latency,
    this.imagePath,
  });

  VoiceChatMessage copyWith({
    String? id,
    String? text,
    String? rawContent,
    String? formattedContent,
    bool? isUser,
    DateTime? timestamp,
    Duration? latency,
    String? imagePath,
  }) {
    return VoiceChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      rawContent: rawContent ?? this.rawContent,
      formattedContent: formattedContent ?? this.formattedContent,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      latency: latency ?? this.latency,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'rawContent': rawContent,
      'formattedContent': formattedContent,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'latency': latency?.inMilliseconds,
      'imagePath': imagePath,
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
      latency: json['latency'] != null
          ? Duration(milliseconds: json['latency'])
          : null,
      imagePath: json['imagePath'],
    );
  }
}