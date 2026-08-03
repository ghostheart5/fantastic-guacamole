import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI state helpers', () {
    test('siClamp01 clamps values and handles null fallback', () {
      expect(siClamp01(2), 1.0);
      expect(siClamp01(-1), 0.0);
      expect(siClamp01(null, fallback: 0.3), 0.3);
    });

    test('siClean and siNormalizeMood sanitize free text input', () {
      expect(siClean('  hello   world  '), 'hello world');
      expect(siClean('   ', fallback: 'fallback'), 'fallback');
      expect(siNormalizeMood('  FOCUSED  '), 'focused');
      expect(siNormalizeMood('   '), 'neutral');
    });

    test('SIState.copyWith preserves invariant clamps', () {
      const SIState base = SIState(energy: 0.4, fatigue: 0.6, completedToday: 2);
      final SIState updated = base.copyWith(
        energy: 9,
        fatigue: -2,
        completedToday: 5,
      );

      expect(updated.energy, 1.0);
      expect(updated.fatigue, 0.0);
      expect(updated.completedToday, 5);
    });
  });
}

