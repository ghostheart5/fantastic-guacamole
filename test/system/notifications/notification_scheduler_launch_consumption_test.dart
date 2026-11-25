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
    'a consumer that arrives before init waits for it; concurrent and repeated consumers query the stable intent once',
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
      // A cold-start tap: the shell mounts before startup init has finished.
      // The read waits for init rather than dropping the tap.
      bool settled = false;
      final first = scheduler.consumeLaunchPayload();
      unawaited(first.then((_) => settled = true));
      await pumpEventQueue();
      expect(queries, 0);
      expect(settled, isFalse);
      await scheduler.init(requestPermissions: false);
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

  test('a held launch is handed out once and cleared for tests', () {
    expect(scheduler.takeHeldLaunchPayload(), isNull);
    scheduler.holdLaunchPayload(payload);
    expect(scheduler.hasHeldLaunchPayload, isTrue);
    expect(scheduler.takeHeldLaunchPayload(), payload);
    expect(scheduler.takeHeldLaunchPayload(), isNull);
    scheduler.holdLaunchPayload(payload);
    scheduler.resetLaunchConsumptionForTesting();
    expect(scheduler.hasHeldLaunchPayload, isFalse);
  });

  test('a held launch is honoured for two minutes after launch, then dropped, '
      'and holding notifies listeners', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      if (call.method == 'getNotificationAppLaunchDetails') {
        return stableNativeResponse;
      }
      return null;
    });
    DateTime now = DateTime(2026, 11, 24, 8);
    NotificationScheduler.launchClock = () => now;
    addTearDown(() => NotificationScheduler.launchClock = DateTime.now);
    await scheduler.init(requestPermissions: false);
    expect(await scheduler.consumeLaunchPayload(), payload);
    var notified = 0;
    void listener() => notified++;
    NotificationScheduler.heldLaunchPayloadListenable.addListener(listener);
    addTearDown(
      () => NotificationScheduler.heldLaunchPayloadListenable.removeListener(
        listener,
      ),
    );

    scheduler.holdLaunchPayload(payload);
    expect(notified, 1);
    now = now.add(NotificationScheduler.heldLaunchPayloadMaxAge);
    expect(scheduler.takeHeldLaunchPayload(), payload);

    scheduler.holdLaunchPayload(payload);
    now = now.add(const Duration(seconds: 1));
    expect(scheduler.takeHeldLaunchPayload(), isNull);
    expect(scheduler.hasHeldLaunchPayload, isFalse);
  });

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
