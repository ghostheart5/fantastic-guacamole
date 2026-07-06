import 'dart:convert';

class FlowmapNode {
  const FlowmapNode({
    required this.id,
    required this.title,
    this.description,
    this.tags = const [],
    this.connectedTo = const [],
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final List<String> connectedTo;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'tags': tags,
    'connectedTo': connectedTo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FlowmapNode.fromJson(Map<String, dynamic> json) => FlowmapNode(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    connectedTo: (json['connectedTo'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String toRaw() => jsonEncode(toJson());

  static FlowmapNode fromRaw(String raw) =>
      FlowmapNode.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  FlowmapNode copyWith({
    String? title,
    String? description,
    List<String>? tags,
    List<String>? connectedTo,
  }) => FlowmapNode(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    connectedTo: connectedTo ?? this.connectedTo,
    createdAt: createdAt,
  );
}
