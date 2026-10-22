import 'dart:async';

import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final scheduler = NotificationScheduler();
  const payload = 'reflection_reminder';
  final stableNativeResponse = <String, Object>{
    'notificationLaunchedApp': true,
    'notificationResponse': <String, Object>{
      'notificationResponseType': 0,
      'payload': payload,
    },
  };
  setUp(() {
    scheduler.resetLaunchConsumptionForTesting();
    scheduler.clearTappedPayload();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    scheduler.clearTappedPayload();
  });

  test(
    'preinit does not claim; concurrent and repeated consumers query the stable intent once',
    () async {
      var queries = 0;
      final entered = Completer<void>();
      final response = Completer<Map<String, Object>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'getNotificationAppLaunchDetails') {
          queries++;
          if (!entered.isCompleted) {
            entered.complete();
          }
          return response.future;
        }
        return null;
      });
      expect(await scheduler.consumeLaunchPayload(), isNull);
      expect(queries, 0);
      await scheduler.init(requestPermissions: false);
      final first = scheduler.consumeLaunchPayload();
      await entered.future;
      expect(await scheduler.consumeLaunchPayload(), isNull);
      response.complete(stableNativeResponse);
      expect(await first, payload);
      expect(await scheduler.consumeLaunchPayload(), isNull);
      await scheduler.init(requestPermissions: false);
      scheduler.clearTappedPayload();
      expect(await scheduler.consumeLaunchPayload(), isNull);
      expect(queries, 1);

      // A later real foreground event must work even with the identical daily id.
      await _deliverForeground(channel, payload);
      expect(NotificationScheduler.tappedPayloadListenable.value, payload);
      scheduler.clearTappedPayload();
      expect(await scheduler.consumeLaunchPayload(), isNull);
      expect(queries, 1);
    },
  );

  test(
    'an ordinary launch is also claimed so a later foreground intent is not replayed as cold',
    () async {
      var queries = 0;
      var launched = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'getNotificationAppLaunchDetails') {
          queries++;
          return launched
              ? stableNativeResponse
              : <String, Object>{'notificationLaunchedApp': false};
        }
        return null;
      });
      await scheduler.init(requestPermissions: false);
      expect(await scheduler.consumeLaunchPayload(), isNull);
      launched = true;
      expect(await scheduler.consumeLaunchPayload(), isNull);
      expect(queries, 1);
    },
  );

  test('an uncertain native read is not retried automatically', () async {
    var queries = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      if (call.method == 'getNotificationAppLaunchDetails') {
        queries++;
        throw PlatformException(code: 'launch-read-unavailable');
      }
      return null;
    });
    await scheduler.init(requestPermissions: false);
    expect(await scheduler.consumeLaunchPayload(), isNull);
    expect(await scheduler.consumeLaunchPayload(), isNull);
    expect(queries, 1);
  });
}

Future<void> _deliverForeground(MethodChannel channel, String payload) async {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('didReceiveNotificationResponse', <String, Object>{
        'notificationResponseType': 0,
        'payload': payload,
      }),
    ),
    null,
  );
}
