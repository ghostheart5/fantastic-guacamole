import 'package:fantastic_guacamole/domain/usecases/calculate_xp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculateXp', () {
    test('returns rounded XP using priority and energy bonus', () {
      final int xp = CalculateXp().call(seconds: 1200, taskPriority: 3, energy: 0.8);

      expect(xp, 27);
    });

    test('returns lower XP at low energy', () {
      final int xp = CalculateXp().call(seconds: 1200, taskPriority: 3, energy: 0.0);

      expect(xp, 15);
    });
  });
}
