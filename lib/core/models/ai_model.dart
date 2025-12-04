class AIModel {
  final String id;
  final String name;
  final String address;
  final bool isDefault;
  final DateTime createdAt;

  AIModel({
    required this.id,
    required this.name,
    required this.address,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AIModel copyWith({
    String? id,
    String? name,
    String? address,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AIModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static AIModel fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
