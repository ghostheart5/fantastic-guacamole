enum SuggestionStatus { proposed, accepted, rejected, dismissed }

class SuggestionEntity {
  SuggestionEntity({
    required this.id,
    required this.title,
    required this.reasoning,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.confidence = 0,
    this.surface = 'system',
    this.status = SuggestionStatus.proposed,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String title;
  final String reasoning;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final double confidence;
  final String surface;
  final SuggestionStatus status;

  SuggestionEntity copyWith({
    String? title,
    String? reasoning,
    double? confidence,
    String? surface,
    DateTime? updatedAt,
    String? userId,
    SuggestionStatus? status,
  }) {
    return SuggestionEntity(
      id: id,
      title: title ?? this.title,
      reasoning: reasoning ?? this.reasoning,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      confidence: confidence ?? this.confidence,
      surface: surface ?? this.surface,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'reasoning': reasoning,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'confidence': confidence,
      'surface': surface,
      'status': status.name,
    };
  }

  factory SuggestionEntity.fromJson(Map<String, dynamic> json) {
    return SuggestionEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Suggestion',
      reasoning: json['reasoning']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userId: json['userId']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      surface: json['surface']?.toString() ?? 'system',
      status: SuggestionStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => SuggestionStatus.proposed,
      ),
    );
  }
}
