import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/domain/value_objects/difficulty.dart';
import 'package:fantastic_guacamole/domain/value_objects/streak_value.dart';
import 'package:fantastic_guacamole/domain/value_objects/user_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report reasons map to stable backend-safe codes', () {
    expect(
      AiContentReportReason.values.map(
        (AiContentReportReason value) => value.code,
      ),
      <String>[
        'unsafe_or_harmful',
        'misleading_or_inaccurate',
        'privacy_concern',
        'other',
      ],
    );
  });

  test('planned domain values accept their documented boundaries', () {
    expect(StreakValue(0).value, 0);
    expect(StreakValue(12).value, 12);
    expect(UserId(' account-7 ').value, 'account-7');
    expect(Difficulty(1).value, 1);
    expect(Difficulty(5).value, 5);
  });

  test('planned domain values reject corrupt identifiers and ranges', () {
    expect(() => StreakValue(-1), throwsArgumentError);
    expect(() => UserId('  '), throwsArgumentError);
    expect(() => Difficulty(0), throwsArgumentError);
    expect(() => Difficulty(6), throwsArgumentError);
  });

  test('domain values use value equality and stable hashes', () {
    expect(UserId('account-7'), UserId(' account-7 '));
    expect(UserId('account-7').hashCode, UserId('account-7').hashCode);
    expect(Difficulty(3), Difficulty(3));
    expect(Difficulty(3), isNot(Difficulty(4)));
    expect(Difficulty(3).toString(), 'Difficulty(3)');
  });
}
