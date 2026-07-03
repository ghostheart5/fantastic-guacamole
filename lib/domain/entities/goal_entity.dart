class GoalEntity {
  const GoalEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.targetDate,
    this.colorHex = 0xFF9B8AFB,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? description;
  final DateTime? targetDate;
  final int colorHex;

  GoalEntity copyWith({
    String? title,
    String? description,
    DateTime? targetDate,
    int? colorHex,
  }) => GoalEntity(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        description: description ?? this.description,
        targetDate: targetDate ?? this.targetDate,
        colorHex: colorHex ?? this.colorHex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        if (description != null) 'description': description,
        if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
        'colorHex': colorHex,
      };

  factory GoalEntity.fromJson(Map<String, dynamic> j) => GoalEntity(
        id: j['id'] as String,
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        description: j['description'] as String?,
        targetDate: j['targetDate'] != null
            ? DateTime.tryParse(j['targetDate'] as String)
            : null,
        colorHex: (j['colorHex'] as num?)?.toInt() ?? 0xFF9B8AFB,
      );
}
