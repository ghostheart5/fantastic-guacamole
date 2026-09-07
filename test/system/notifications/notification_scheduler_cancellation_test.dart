import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Production registers the Dart platform implementation automatically. A
  // widget-test isolate must register it before exercising the method channel.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'cold cancellation reaches Android with stable account-scoped IDs',
    () async {
      final scheduler = NotificationScheduler();
      expect(
        await scheduler.cancel('daily', accountScope: 'account-a'),
        isTrue,
      );
      expect(
        await scheduler.cancel('daily', accountScope: 'account-a'),
        isTrue,
      );
      expect(
        await scheduler.cancel('daily', accountScope: 'account-b'),
        isTrue,
      );
      expect(calls.map((call) => call.method), ['cancel', 'cancel', 'cancel']);
      final first = (calls[0].arguments as Map)['id'];
      expect(first, isA<int>());
      expect((calls[1].arguments as Map)['id'], first);
      expect((calls[2].arguments as Map)['id'], isNot(first));
    },
  );

  test(
    'cold cancel-all reaches Android without permission or initialization',
    () async {
      expect(await NotificationScheduler().cancelAll(), isTrue);
      expect(calls.map((call) => call.method), ['cancelAll']);
    },
  );

  test(
    'cancellation propagates a platform failure instead of reporting success',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'cancel-failed');
          });
      await expectLater(
        NotificationScheduler().cancel('daily', accountScope: 'account-a'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'cancel-failed',
          ),
        ),
      );
      expect(calls.map((call) => call.method), ['cancel']);
    },
  );
}
