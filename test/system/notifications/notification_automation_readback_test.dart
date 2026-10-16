import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  test(
    'automation readback includes only native registrations for current account',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var allowed = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'areNotificationsEnabled') return allowed;
            if (call.method == 'pendingNotificationRequests') {
              return [
                {
                  'id': 1,
                  'title': 'Daily Planning Reminder',
                  'body': 'Plan',
                  'payload': NotificationScheduler.accountPayload(
                    'owner-a',
                    'daily_planning_reminder',
                    dailyHour: 7,
                    dailyMinute: 30,
                  ),
                },
                {
                  'id': 2,
                  'title': 'Other account',
                  'body': 'Private',
                  'payload': NotificationScheduler.accountPayload(
                    'owner-b',
                    'habit_reminder_daily',
                  ),
                },
                {
                  'id': 3,
                  'title': 'Unscoped',
                  'body': 'Legacy',
                  'payload': 'daily_planning_reminder',
                },
              ];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final rows = await NotificationScheduler().pendingForAccount('owner-a');
      expect(rows, hasLength(1));
      expect(rows.single.id, 'daily_planning_reminder');
      expect(rows.single.hour, 7);
      expect(rows.single.minute, 30);
      allowed = false;
      expect(
        await NotificationScheduler().pendingForAccount('owner-a'),
        isEmpty,
      );
    },
  );
}
