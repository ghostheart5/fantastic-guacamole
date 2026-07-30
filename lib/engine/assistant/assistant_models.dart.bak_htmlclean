class AssistantIntent {
  const AssistantIntent({
    required this.label,
    required this.confidence,
    this.surface,
    this.metadata = const <String, dynamic>{},
  });

  final String label;
  final double confidence;
  final String? surface;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'confidence': confidence,
      if (surface != null) 'surface': surface,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class AssistantContext {
  const AssistantContext({
    required this.surface,
    required this.intent,
    required this.query,
    required this.metadata,
  });

  final String surface;
  final AssistantIntent intent;
  final String query;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'surface': surface,
      'intent': intent.toJson(),
      'query': query,
      'metadata': metadata,
    };
  }
}
