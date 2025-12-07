class AIModel {
  final String id;
  final String name;
  final String address;
  final bool isDefault;
  final DateTime createdAt;

  // NEW: Backend Preference Flag
  // null = Unknown (Auto-detect)
  // true = GPU
  // false = CPU (Fallback mode)
  final bool? isGpuSupported;

  AIModel({
    required this.id,
    required this.name,
    required this.address,
    this.isDefault = false,
    DateTime? createdAt,
    this.isGpuSupported,
  }) : createdAt = createdAt ?? DateTime.now();

  AIModel copyWith({
    String? id,
    String? name,
    String? address,
    bool? isDefault,
    DateTime? createdAt,
    bool? isGpuSupported,
  }) {
    return AIModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      isGpuSupported: isGpuSupported ?? this.isGpuSupported,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'isGpuSupported': isGpuSupported,
    };
  }

  static AIModel fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      isGpuSupported: json['isGpuSupported'],
    );
  }
}