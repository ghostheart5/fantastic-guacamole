// lib/engine/si/prediction.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class Prediction {
  const Prediction({
    required this.outcome,
    required this.probability,
    required this.explanation,
    this.confidence = 0.5,
    this.sampleSize = 0,
    this.signals = const <String>[],
  });

  final String outcome;
  final double probability;
  final String explanation;
  final double confidence;
  final int sampleSize;
  final List<String> signals;

  double get safeProbability => siClamp01(probability);
  double get safeConfidence => siClamp01(confidence);

  bool get reliable => sampleSize >= 3 && safeConfidence >= 0.55;

  Prediction copyWith({
    String? outcome,
    double? probability,
    String? explanation,
    double? confidence,
    int? sampleSize,
    List<String>? signals,
  }) {
    return Prediction(
      outcome: outcome ?? this.outcome,
      probability: siClamp01(probability ?? this.probability),
      explanation: explanation ?? this.explanation,
      confidence: siClamp01(confidence ?? this.confidence),
      sampleSize: sampleSize ?? this.sampleSize,
      signals: signals ?? this.signals,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'outcome': outcome,
    'probability': safeProbability,
    'explanation': explanation,
    'confidence': safeConfidence,
    'sample_size': sampleSize,
    'signals': signals,
    'reliable': reliable,
  };
}
