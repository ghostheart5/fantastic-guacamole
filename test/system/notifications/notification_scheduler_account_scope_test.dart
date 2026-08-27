import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account payload round-trips owner scope and logical id', () {
    final String payload = NotificationScheduler.accountPayload(
      'owner-scope',
      'goal_reminder_goal-1',
    );

    expect(NotificationScheduler.parseAccountPayload(payload), (
      accountScope: 'owner-scope',
      notificationId: 'goal_reminder_goal-1',
    ));
  });

  test('malformed or legacy payload is not accepted as account-scoped', () {
    expect(NotificationScheduler.parseAccountPayload('{bad-json'), isNull);
    expect(
      NotificationScheduler.parseAccountPayload('goal_reminder_goal-1'),
      isNull,
    );
  });
}
