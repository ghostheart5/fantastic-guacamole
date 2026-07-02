class NeuralEntry {
  NeuralEntry({
    required this.task,
    required this.reasoning,
    required this.confidence,
    required this.duration,
    required this.quality,
    required this.timestamp,
  });

  final String task;
  final String reasoning;
  final double confidence;
  final int duration;
  final double quality;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'task': task,
      'reasoning': reasoning,
      'confidence': confidence,
      'duration': duration,
      'quality': quality,
      'timestamp': timestamp.toIso8601String(),
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
    );
  }
}
