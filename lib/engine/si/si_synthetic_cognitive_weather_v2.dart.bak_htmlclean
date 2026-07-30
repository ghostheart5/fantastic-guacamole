// lib/engine/si/si_synthetic_cognitive_weather_v2.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum SyntheticWeatherV2 { clear, focused, foggy, storm, recovery }

class SyntheticWeatherReportV2 {
  const SyntheticWeatherReportV2({
    required this.weather,
    required this.pressure,
    required this.guidance,
    required this.memory,
  });
  final SyntheticWeatherV2 weather;
  final double pressure;
  final String guidance;
  final SIMemoryStore memory;
}

class SISyntheticCognitiveWeatherV2 {
  const SISyntheticCognitiveWeatherV2();

  SyntheticWeatherReportV2 evaluate({
    required SIContext context,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final pressure = siClamp01(
      context.userState.stress * .35 +
          context.userState.cognitiveLoad * .35 +
          context.userState.fatigue * .2 +
          (instinct.safetyFirst ? .1 : 0),
    );
    final w = pressure >= .72
        ? SyntheticWeatherV2.storm
        : context.userState.fatigue >= .68
        ? SyntheticWeatherV2.recovery
        : context.userState.engagement >= .68
        ? SyntheticWeatherV2.focused
        : context.userState.cognitiveLoad >= .6
        ? SyntheticWeatherV2.foggy
        : SyntheticWeatherV2.clear;
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_weather_v2|${w.name}|pressure=${pressure.toStringAsFixed(2)}',
            timestamp: t,
            relevance: 1 - pressure,
            confidence: .72,
            emotionalWeight: pressure,
            reinforcement: w == SyntheticWeatherV2.focused ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);
    return SyntheticWeatherReportV2(
      weather: w,
      pressure: pressure,
      guidance: _g(w),
      memory: next,
    );
  }

  String _g(SyntheticWeatherV2 w) => switch (w) {
    SyntheticWeatherV2.storm => 'stabilize_and_shorten',
    SyntheticWeatherV2.recovery => 'protect_capacity',
    SyntheticWeatherV2.focused => 'protect_focus',
    SyntheticWeatherV2.foggy => 'clarify_one_detail',
    _ => 'continue_steady',
  };
}
