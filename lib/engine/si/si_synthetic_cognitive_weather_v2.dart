class CognitiveWeatherV2 {
  const CognitiveWeatherV2({
    required this.emotionalClimate,
    required this.cognitiveStorms,
    required this.narrativeSeasons,
    required this.intentWinds,
    required this.memoryHumidity,
  });

  final String emotionalClimate;
  final List<String> cognitiveStorms;
  final String narrativeSeasons;
  final String intentWinds;
  final double memoryHumidity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional_climate': emotionalClimate,
      'cognitive_storms': cognitiveStorms,
      'narrative_seasons': narrativeSeasons,
      'intent_winds': intentWinds,
      'memory_humidity': memoryHumidity,
    };
  }
}

class SyntheticCognitiveWeatherV2 {
  const SyntheticCognitiveWeatherV2();

  CognitiveWeatherV2 forecast({
    required String mood,
    required String intent,
    required double confidence,
  }) {
    return CognitiveWeatherV2(
      emotionalClimate: mood,
      cognitiveStorms: <String>[if (mood == 'stressed') 'overload_storm'],
      narrativeSeasons: intent == 'reflect'
          ? 'autumn_reflection'
          : 'spring_execution',
      intentWinds: intent,
      memoryHumidity: (1 - confidence).clamp(0.0, 1.0),
    );
  }
}
