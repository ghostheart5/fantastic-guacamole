import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/user_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XP source totals survive profile serialization', () {
    final ProfileState original = ProfileState(
      xp: 75,
      xpBySource: const <String, int>{
        'task_completion': 50,
        'goal_completed': 25,
      },
    );

    final ProfileState restored = ProfileState.fromJson(original.toJson());

    expect(restored.xpBySource, original.xpBySource);
  });

  test('a broken streak keeps history visible without punitive copy', () {
    const UserProgress progress = UserProgress(
      xp: 120,
      level: 2,
      streak: 0,
      longestStreak: 8,
    );

    expect(progress.streakMessage, contains('history remains'));
    expect(progress.streakMessage, isNot(contains('broke')));
  });
}
