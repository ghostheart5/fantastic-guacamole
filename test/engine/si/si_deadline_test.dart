import 'package:fantastic_guacamole/engine/si/si_deadline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a timed deadline whose UTC time is midnight is past from that '
      'moment, not a whole day', () {
    final due = DateTime.utc(2026, 9, 17);
    expect(siDeadlinePast(due, null, DateTime.utc(2026, 9, 16, 23, 59)), false);
    expect(siDeadlinePast(due, null, DateTime.utc(2026, 9, 17, 0, 1)), true);
  });

  test('a whole-day deadline is past only once its local day has ended', () {
    final day = DateTime(2026, 9, 17);
    expect(siDeadlinePast(day, day, DateTime(2026, 9, 17, 23, 59)), false);
    expect(siDeadlinePast(day, day, DateTime(2026, 9, 18, 0, 1)), true);
  });

  test('a goal is late once its target day has ended, its time aside', () {
    final morning = DateTime(2026, 9, 17, 8);
    expect(siGoalLate(morning, null, DateTime(2026, 9, 17, 12)), false);
    expect(siGoalLate(morning, null, DateTime(2026, 9, 18, 0, 1)), true);
    // The saved calendar day decides when there is one.
    expect(
      siGoalLate(
        DateTime(2026, 9, 20, 12),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 17, 12),
      ),
      true,
    );
  });
}
