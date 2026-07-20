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

  static FlowmapNode? tryFromRaw(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final String? id = decoded['id']?.toString();
      final String? title = decoded['title']?.toString();
      final String? createdAtRaw = decoded['createdAt']?.toString();
      final DateTime? createdAt = createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw);
      if (id == null || title == null || createdAt == null) {
        return null;
      }
      return FlowmapNode(
        id: id,
        title: title,
        description: decoded['description']?.toString(),
        tags: (decoded['tags'] as List<dynamic>?)
                ?.map((dynamic e) => e.toString())
                .toList(growable: false) ??
            const <String>[],
        connectedTo: (decoded['connectedTo'] as List<dynamic>?)
                ?.map((dynamic e) => e.toString())
                .toList(growable: false) ??
            const <String>[],
        createdAt: createdAt,
      );
    } on Object {
      return null;
    }
  }

  static FlowmapNode fromRaw(String raw) {
    final FlowmapNode? node = tryFromRaw(raw);
    if (node == null) {
      throw const FormatException('Invalid flowmap node payload');
    }
    return node;
  }

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
