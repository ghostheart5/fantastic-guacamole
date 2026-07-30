// lib/engine/si/si_user_state_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class UserStateRefinement {
  const UserStateRefinement({
    required this.context,
    required this.adjustments,
    required this.confidence,
  });

  final SIContext context;
  final List<String> adjustments;
  final double confidence;
}

class SIUserStateEngine {
  const SIUserStateEngine();

  UserStateRefinement refine({
    required SIContext context,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learningWeights,
  }) {
    final List<String> adjustments = <String>[];
    final SIUserState u = context.userState;

    double stress = siClamp01(u.stress);
    double load = siClamp01(u.cognitiveLoad);
    double motivation = siClamp01(u.motivation);
    double engagement = siClamp01(u.engagement);
    double fatigue = siClamp01(u.fatigue);
    double frustration = siClamp01(u.frustration);
    double excitement = siClamp01(u.excitement);

    final Iterable<MicroPattern> found =
        patterns?.patterns ?? const <MicroPattern>[];

    for (final MicroPattern p in found) {
      switch (p.type) {
        case MicroPatternType.fatigueDrift:
          fatigue = _raise(fatigue, p.strength, 0.25);
          load = _raise(load, p.strength, 0.18);
          adjustments.add('fatigue_pattern_applied');
          break;
        case MicroPatternType.highLoadLoop:
          stress = _raise(stress, p.strength, 0.2);
          load = _raise(load, p.strength, 0.25);
          adjustments.add('high_load_pattern_applied');
          break;
        case MicroPatternType.completionMomentum:
          motivation = _raise(motivation, p.strength, 0.2);
          engagement = _raise(engagement, p.strength, 0.16);
          adjustments.add('momentum_pattern_applied');
          break;
        case MicroPatternType.skipResistance:
          frustration = _raise(frustration, p.strength, 0.16);
          motivation = _lower(motivation, p.strength, 0.12);
          adjustments.add('resistance_pattern_applied');
          break;
        case MicroPatternType.stableFocus:
          engagement = _raise(engagement, p.strength, 0.18);
          stress = _lower(stress, p.strength, 0.12);
          adjustments.add('stable_focus_pattern_applied');
          break;
        case MicroPatternType.repeatedTopic:
        case MicroPatternType.taskAffinity:
          break;
      }
    }

    if (learningWeights != null) {
      motivation = _raise(motivation, learningWeights.momentum, 0.12);
      fatigue = _raise(fatigue, learningWeights.fatigueSensitivity, 0.1);
      engagement = _raise(engagement, learningWeights.focusReadiness, 0.12);

      if (learningWeights.resistance >= 0.65) {
        frustration = _raise(frustration, learningWeights.resistance, 0.12);
      }

      adjustments.add('adaptive_learning_applied');
    }

    final int recentFallbacks = memory.tiered.shortTerm
        .where((MemoryRecord r) => r.content.contains('engine_fallback'))
        .length;

    if (recentFallbacks >= 2) {
      stress = _raise(stress, 0.7, 0.12);
      load = _raise(load, 0.65, 0.1);
      adjustments.add('recent_fallbacks_applied');
    }

    final String emotion = _emotion(
      original: u.emotion,
      stress: stress,
      load: load,
      fatigue: fatigue,
      frustration: frustration,
      excitement: excitement,
    );

    final SIUserState refined = SIUserState(
      emotion: emotion,
      cognitiveLoad: load,
      stress: stress,
      motivation: motivation,
      engagement: engagement,
      fatigue: fatigue,
      frustration: frustration,
      excitement: excitement,
      stability: _stability(stress: stress, load: load, engagement: engagement),
    );

    return UserStateRefinement(
      context: SIContext(input: context.input, userState: refined),
      adjustments: List<String>.unmodifiable(adjustments),
      confidence: _confidence(adjustments, patterns),
    );
  }

  double _raise(double current, double signal, double rate) {
    return siClamp01(current + siClamp01(signal) * rate);
  }

  double _lower(double current, double signal, double rate) {
    return siClamp01(current - siClamp01(signal) * rate);
  }

  String _emotion({
    required String original,
    required double stress,
    required double load,
    required double fatigue,
    required double frustration,
    required double excitement,
  }) {
    if (stress >= 0.68 || frustration >= 0.68) return 'stressed';
    if (load >= 0.72) return 'confused';
    if (fatigue >= 0.72 && excitement < 0.45) return 'tired';
    if (excitement >= 0.68 && stress < 0.5) return 'excited';
    return siNormalizeMood(original);
  }

  String _stability({
    required double stress,
    required double load,
    required double engagement,
  }) {
    if (stress >= 0.7 || load >= 0.75) return 'fragile';
    if (engagement >= 0.65 && stress <= 0.45) return 'stable';
    return 'volatile';
  }

  double _confidence(List<String> adjustments, MicroPatternReport? patterns) {
    final double base = adjustments.isEmpty ? 0.55 : 0.68;
    final double patternBoost = patterns == null
        ? 0
        : patterns.patterns.length.clamp(0, 4) * 0.06;
    return siClamp01(base + patternBoost);
  }
}
