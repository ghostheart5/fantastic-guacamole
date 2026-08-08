import 'package:fantastic_guacamole/domain/usecases/extract_si_signals.dart';
import 'package:flutter_test/flutter_test.dart';

SiSignals _extract({
  double pressureIndex = 0,
  double behaviorDivergence = 0,
  double energy = 0.7,
  int streak = 0,
  bool hasGoals = false,
  int skippedTaskCount = 0,
  String emotion = 'neutral',
  String insightsSummary = '',
}) {
  return const ExtractSiSignals()(
    pressureIndex: pressureIndex,
    behaviorDivergence: behaviorDivergence,
    energy: energy,
    streak: streak,
    hasGoals: hasGoals,
    skippedTaskCount: skippedTaskCount,
    emotion: emotion,
    insightsSummary: insightsSummary,
  );
}

void main() {
  group('friction and overwhelm thresholds', () {
    test('friction triggers at pressure 60 or low energy', () {
      expect(_extract(pressureIndex: 59, energy: 0.5).friction, isFalse);
      expect(_extract(pressureIndex: 60, energy: 0.5).friction, isTrue);
      expect(_extract(pressureIndex: 0, energy: 0.34).friction, isTrue);
      expect(_extract(pressureIndex: 0, energy: 0.35).friction, isFalse);
    });

    test('overwhelm triggers at pressure 75 or divergence 50', () {
      expect(_extract(pressureIndex: 74, behaviorDivergence: 49).overwhelm, isFalse);
      expect(_extract(pressureIndex: 75).overwhelm, isTrue);
      expect(_extract(behaviorDivergence: 50).overwhelm, isTrue);
    });
  });

  group('streak health banding', () {
    test('uses fragile / stable / strong bands', () {
      expect(_extract(streak: 2).streakHealth, 'fragile');
      expect(_extract(streak: 3).streakHealth, 'stable');
      expect(_extract(streak: 9).streakHealth, 'stable');
      expect(_extract(streak: 10).streakHealth, 'strong');
    });
  });

  group('goal drift and task avoidance', () {
    test('goal drift requires goals and divergence 40', () {
      expect(_extract(hasGoals: false, behaviorDivergence: 90).goalDrift, isFalse);
      expect(_extract(hasGoals: true, behaviorDivergence: 39).goalDrift, isFalse);
      expect(_extract(hasGoals: true, behaviorDivergence: 40).goalDrift, isTrue);
    });

    test('task avoidance requires two or more skips', () {
      expect(_extract(skippedTaskCount: 1).taskAvoidance, isFalse);
      expect(_extract(skippedTaskCount: 2).taskAvoidance, isTrue);
    });
  });

  group('emotional classification', () {
    test('classifies strain emotions', () {
      for (final String emotion in ExtractSiSignals.strainEmotions) {
        final SiSignals signals = _extract(emotion: emotion);
        expect(signals.emotionalStrain, isTrue, reason: emotion);
        expect(signals.emotionalStability, isFalse, reason: emotion);
        expect(signals.emotionalPatterns, contains('emotional_strain'));
      }
    });

    test('classifies stability emotions', () {
      for (final String emotion in ExtractSiSignals.stabilityEmotions) {
        final SiSignals signals = _extract(emotion: emotion);
        expect(signals.emotionalStability, isTrue, reason: emotion);
        expect(signals.emotionalStrain, isFalse, reason: emotion);
        expect(signals.emotionalPatterns, contains('emotional_stability'));
      }
    });

    test('an unknown emotion is neither strain nor stability', () {
      final SiSignals signals = _extract(emotion: 'unmapped');
      expect(signals.emotionalStrain, isFalse);
      expect(signals.emotionalStability, isFalse);
      expect(signals.emotion, 'unmapped');
    });
  });

  group('pattern detection', () {
    test('detects overload from the insights summary, case-insensitively', () {
      expect(
        _extract(insightsSummary: 'Heavy OVERLOAD detected').emotionalPatterns,
        contains('overload_pattern'),
      );
      expect(
        _extract(insightsSummary: 'all clear').emotionalPatterns,
        isNot(contains('overload_pattern')),
      );
    });

  });

  group('equivalence with the previous inline provider logic', () {
    // Mirrors si_pipeline_provider's original expressions so a threshold change
    // cannot silently alter SI Console behaviour.
    bool legacyFriction(double pressure, double energy) =>
        pressure >= 60 || energy < 0.35;
    bool legacyOverwhelm(double pressure, double divergence) =>
        pressure >= 75 || divergence >= 50;
    String legacyStreak(int streak) =>
        streak >= 10 ? 'strong' : (streak >= 3 ? 'stable' : 'fragile');

    test('matches the legacy expressions across a grid of inputs', () {
      for (final double pressure in <double>[0, 59, 60, 74, 75, 100]) {
        for (final double divergence in <double>[0, 39, 40, 49, 50]) {
          for (final double energy in <double>[0.1, 0.34, 0.35, 0.9]) {
            for (final int streak in <int>[0, 2, 3, 9, 10]) {
              final SiSignals signals = _extract(
                pressureIndex: pressure,
                behaviorDivergence: divergence,
                energy: energy,
                streak: streak,
              );
              expect(signals.friction, legacyFriction(pressure, energy));
              expect(signals.overwhelm, legacyOverwhelm(pressure, divergence));
              expect(signals.streakHealth, legacyStreak(streak));
            }
          }
        }
      }
    });
  });
}
