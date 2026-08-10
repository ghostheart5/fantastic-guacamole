import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressionPolicy', () {
    test('uses the documented XP-to-level curve', () {
      expect(ProgressionPolicy.levelFromXp(0), 1);
      expect(ProgressionPolicy.levelFromXp(100), 2);
      expect(ProgressionPolicy.levelFromXp(400), 3);
      expect(ProgressionPolicy.xpForLevel(3), 400);
    });
  });
}
