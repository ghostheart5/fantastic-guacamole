// lib/engine/si/si_emotion_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class EmotionModulation {
  const EmotionModulation({
    required this.signal,
    required this.outputPressure,
    required this.recommendedModifier,
    required this.shouldSoften,
  });

  final EmotionalSignal signal;
  final double outputPressure;
  final String recommendedModifier;
  final bool shouldSoften;
}

class SIEmotionEngine {
  const SIEmotionEngine();

  EmotionModulation infer({
    required SIContext context,
    String? text,
    String? previousMood,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
  }) {
    final String lower = (text ?? context.input.text).toLowerCase();
    final SIUserState u = context.userState;
    final SILatentInputs l = context.input.latent;

    double stress = _max(<double>[
      u.stress,
      u.frustration,
      l.frustration,
      lower.contains('overwhelmed') ? 0.75 : 0,
      lower.contains('stressed') ? 0.62 : 0,
    ]);

    double confusion = _max(<double>[
      l.confusion,
      u.cognitiveLoad >= 0.75 ? 0.68 : 0,
      lower.contains('confused') || lower.contains('lost') ? 0.62 : 0,
    ]);

    double excitement = _max(<double>[
      u.excitement,
      l.excitement,
      lower.contains('excited') ? 0.58 : 0,
      lower.contains('ready') ? 0.45 : 0,
    ]);

    double fatigue = _max(<double>[
      u.fatigue,
      l.hesitation,
      lower.contains('tired') ? 0.65 : 0,
      lower.contains('drained') ? 0.72 : 0,
    ]);

    for (final MicroPattern p in patterns?.patterns ?? const <MicroPattern>[]) {
      if (p.type == MicroPatternType.fatigueDrift) {
        fatigue = _raise(fatigue, p.strength, .18);
      }
      if (p.type == MicroPatternType.highLoadLoop) {
        stress = _raise(stress, p.strength, .16);
      }
      if (p.type == MicroPatternType.stableFocus) {
        excitement = _raise(excitement, p.strength, .1);
      }
    }

    if (learning != null) {
      fatigue = _raise(fatigue, learning.fatigueSensitivity, .08);
      stress = _raise(stress, learning.resistance, .06);
      excitement = _raise(excitement, learning.momentum, .06);
    }

    String mood = siNormalizeMood(u.emotion);
    if (stress >= 0.66) {
      mood = 'stressed';
    } else if (confusion >= 0.62) {
      mood = 'confused';
    } else if (fatigue >= 0.7 && excitement < 0.45) {
      mood = 'tired';
    } else if (excitement >= 0.65 && stress < 0.5) {
      mood = 'excited';
    } else if (!_known(mood)) {
      mood = 'neutral';
    }

    final String previous = previousMood == null
        ? ''
        : siNormalizeMood(previousMood);
    final EmotionalSignal signal = EmotionalSignal(
      mood: mood,
      intensity: _max(<double>[stress, confusion, excitement, fatigue]),
      shift: previous.isEmpty || previous == mood
          ? 'stable'
          : '$previous->$mood',
    );

    return EmotionModulation(
      signal: signal,
      outputPressure: _pressure(signal),
      recommendedModifier: _modifier(signal),
      shouldSoften: mood == 'stressed' || mood == 'confused' || mood == 'tired',
    );
  }

  double _pressure(EmotionalSignal s) {
    switch (s.mood) {
      case 'stressed':
      case 'confused':
      case 'tired':
        return 0.18;
      case 'excited':
        return 0.52;
      default:
        return 0.36;
    }
  }

  String _modifier(EmotionalSignal s) {
    switch (s.mood) {
      case 'stressed':
        return 'No pressure — one small move.';
      case 'confused':
        return 'I’ll keep it step-by-step.';
      case 'tired':
        return 'Keep the scope light.';
      case 'excited':
        return 'Use the momentum, but keep the scope clear.';
      default:
        return '';
    }
  }

  double _max(List<double> values) {
    double result = 0;
    for (final double v in values) {
      final double safe = siClamp01(v, fallback: 0);
      if (safe > result) result = safe;
    }
    return result;
  }

  double _raise(double current, double signal, double rate) {
    return siClamp01(current + siClamp01(signal) * rate);
  }

  bool _known(String mood) {
    return mood == 'neutral' ||
        mood == 'stressed' ||
        mood == 'confused' ||
        mood == 'excited' ||
        mood == 'frustrated' ||
        mood == 'calm' ||
        mood == 'tired';
  }
}
