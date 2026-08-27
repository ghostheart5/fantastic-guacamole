import 'package:fantastic_guacamole/state/models/streak.dart';
import 'package:fantastic_guacamole/state/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakService', () {
    const StreakService service = StreakService();

    test('didBreak returns true when user misses more than one day', () {
      final Streak streak = Streak(
        current: 5,
        longest: 8,
        lastActiveDate: DateTime.utc(2026, 7, 3),
      );

      expect(service.didBreak(streak, DateTime.utc(2026, 7, 6)), isTrue);
      expect(service.didBreak(streak, DateTime.utc(2026, 7, 4)), isFalse);
    });
  });
}
