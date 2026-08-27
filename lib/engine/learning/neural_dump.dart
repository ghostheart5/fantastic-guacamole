class NeuralEntry {
  NeuralEntry({
    required this.task,
    required this.reasoning,
    required this.confidence,
    required this.duration,
    required this.quality,
    required this.timestamp,
    this.completed,
  });

  final String task;
  final String reasoning;
  final double confidence;
  final int duration;
  final double quality;
  final DateTime timestamp;

  /// Explicit observed task outcome. Older records predate this field and
  /// represent completed tasks only.
  final bool? completed;

  bool get observedCompleted =>
      completed ?? reasoning.toLowerCase().contains('completed task');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'task': task,
      'reasoning': reasoning,
      'confidence': confidence,
      'duration': duration,
      'quality': quality,
      'timestamp': timestamp.toIso8601String(),
      if (completed != null) 'completed': completed,
    };
  }

  factory NeuralEntry.fromJson(Map<String, dynamic> json) {
    return NeuralEntry(
      task: (json['task'] ?? '').toString(),
      reasoning: (json['reasoning'] ?? '').toString(),
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      quality: ((json['quality'] as num?) ?? 0).toDouble(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      completed: json['completed'] as bool?,
    );
  }
}
