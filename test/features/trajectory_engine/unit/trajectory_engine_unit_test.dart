import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MomentumEngineState', () {
    test('trend helpers are mutually consistent', () {
      const MomentumEngineState rising = MomentumEngineState(
        score: 72,
        trend: 'Rising',
        recovery: 'Recovered',
        forecast: 'Positive.',
        energyPercent: 70,
        pressurePercent: 30,
        streak: 5,
        completedToday: 3,
      );

      expect(rising.isRising, isTrue);
      expect(rising.isStable, isFalse);
      expect(rising.isDeclining, isFalse);
    });

    test('stable and declining trends map correctly', () {
      const MomentumEngineState stable = MomentumEngineState(
        score: 52,
        trend: 'Stable',
        recovery: 'Watch Load',
        forecast: 'Steady.',
        energyPercent: 55,
        pressurePercent: 48,
        streak: 2,
        completedToday: 1,
      );
      const MomentumEngineState declining = MomentumEngineState(
        score: 34,
        trend: 'Declining',
        recovery: 'Recovery Needed',
        forecast: 'Recover first.',
        energyPercent: 36,
        pressurePercent: 82,
        streak: 0,
        completedToday: 0,
      );

      expect(stable.isStable, isTrue);
      expect(stable.isRising, isFalse);
      expect(declining.isDeclining, isTrue);
      expect(declining.isStable, isFalse);
    });
  });
}

