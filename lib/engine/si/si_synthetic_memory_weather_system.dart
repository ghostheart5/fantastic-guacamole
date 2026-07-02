class MemoryWeather {
  const MemoryWeather({
    required this.type,
    required this.intensity,
    required this.reasoningImpact,
  });

  final String type;
  final double intensity;
  final String reasoningImpact;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'intensity': intensity,
      'reasoning_impact': reasoningImpact,
    };
  }
}

class SyntheticMemoryWeatherSystem {
  const SyntheticMemoryWeatherSystem();

  MemoryWeather forecast({
    required String mood,
    required bool memoryConflict,
    required double confidence,
  }) {
    if (memoryConflict) {
      return const MemoryWeather(
        type: 'turbulence',
        intensity: 0.78,
        reasoningImpact: 'Slow reasoning and reconcile conflicting traces.',
      );
    }
    if (mood == 'stressed') {
      return const MemoryWeather(
        type: 'storm',
        intensity: 0.74,
        reasoningImpact: 'Prioritize stabilization and simplified recall.',
      );
    }
    if (confidence < 0.5) {
      return const MemoryWeather(
        type: 'fog',
        intensity: 0.62,
        reasoningImpact: 'Increase clarification and confidence checks.',
      );
    }
    if (confidence > 0.75) {
      return const MemoryWeather(
        type: 'clarity',
        intensity: 0.8,
        reasoningImpact: 'Trust high-relevance memory paths.',
      );
    }
    return const MemoryWeather(
      type: 'calm',
      intensity: 0.45,
      reasoningImpact: 'Use balanced retrieval and pattern matching.',
    );
  }
}
