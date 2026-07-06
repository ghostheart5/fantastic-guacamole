import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStoreBackend backend;
  late NotificationsRepository repository;
  late List<String> cancelledIds;
  late int cancelAllCalls;
  late int scheduleCalls;

  setUp(() {
    backend = InMemorySecureStoreBackend();
    cancelledIds = <String>[];
    cancelAllCalls = 0;
    scheduleCalls = 0;
    repository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: backend),
      scheduleNotification: (NotificationEntity _) async {
        scheduleCalls += 1;
      },
      cancelScheduledNotification: (String id) async {
        cancelledIds.add(id);
      },
      cancelAllScheduledNotifications: () async {
        cancelAllCalls += 1;
      },
    );
  });

  test('starts empty when storage has no records', () async {
    expect(await repository.getNotifications(), isEmpty);
  });

  test('scheduleNotification persists and keeps most recent value by id', () async {
    final now = DateTime.utc(2026, 7, 5, 10);
    await repository.scheduleNotification(
      NotificationEntity(id: 'n-1', title: 'First', message: 'A', scheduledAt: now),
    );
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'n-1',
        title: 'Updated',
        message: 'B',
        scheduledAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final entries = await repository.getNotifications();
    expect(scheduleCalls, 2);
    expect(entries, hasLength(1));
    expect(entries.single.title, 'Updated');
  });

  test('returns empty notifications when persisted storage is corrupt', () async {
    await SecureStore(backend: backend).writeString('notification_entries_v1', '{not-json');

    final List<NotificationEntity> entries = await Logger.withMutedErrors(
      () => repository.getNotifications(),
    );

    expect(entries, isEmpty);
  });

  test('skips malformed map items and keeps valid notifications', () async {
    await SecureStore(backend: backend).writeString(
      'notification_entries_v1',
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'ok',
          'title': 'Valid',
          'message': 'Valid message',
          'scheduledAt': DateTime.utc(2026, 7, 5).toIso8601String(),
          'isEnabled': true,
          'isRead': false,
        },
        <String, Object?>{
          'id': 'bad',
          'title': 'Broken',
          'message': 'Broken message',
          'scheduledAt': 'not-a-date',
          'isEnabled': true,
          'isRead': false,
        },
      ]),
    );

    final entries = await repository.getNotifications();
    expect(entries, hasLength(1));
    expect(entries.single.id, 'ok');
  });

  test('cancelNotification disables existing entry without deleting it', () async {
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'cancel-me',
        title: 'Cancel',
        message: 'Disable only',
        scheduledAt: DateTime.utc(2026, 7, 5, 11),
      ),
    );

    await repository.cancelNotification('cancel-me');

    final entries = await repository.getNotifications();
    expect(cancelledIds, <String>['cancel-me']);
    expect(entries, hasLength(1));
    expect(entries.single.isEnabled, isFalse);
  });

  test('markRead updates read flag in storage', () async {
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'mark-read',
        title: 'Read me',
        message: 'Mark as read',
        scheduledAt: DateTime.utc(2026, 7, 5, 12),
      ),
    );

    await repository.markRead('mark-read');

    final entries = await repository.getNotifications();
    expect(entries.single.isRead, isTrue);
  });

  test('cancelAll disables all notifications and invokes scheduler hook', () async {
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'all-1',
        title: 'One',
        message: 'One',
        scheduledAt: DateTime.utc(2026, 7, 5, 13),
      ),
    );
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'all-2',
        title: 'Two',
        message: 'Two',
        scheduledAt: DateTime.utc(2026, 7, 5, 14),
      ),
    );

    await repository.cancelAll();

    final entries = await repository.getNotifications();
    expect(cancelAllCalls, 1);
    expect(entries.every((entry) => !entry.isEnabled), isTrue);
  });

  test('cancelNotification and markRead are safe no-ops when id is missing', () async {
    await repository.cancelNotification('missing');
    await repository.markRead('missing');

    expect(await repository.getNotifications(), isEmpty);
    expect(cancelledIds, <String>['missing']);
  });

  test('delete removes entry and calls scheduler hook', () async {
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'delete-me',
        title: 'Delete me',
        message: 'Delete',
        scheduledAt: DateTime.utc(2026, 7, 5, 15),
      ),
    );

    await repository.delete('delete-me');

    final entries = await repository.getNotifications();
    expect(entries, isEmpty);
    expect(cancelledIds, contains('delete-me'));
  });

  test('scheduler fallback branches execute without wrapper hooks', () async {
    final fallbackRepository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: InMemorySecureStoreBackend()),
    );

    await fallbackRepository.scheduleNotification(
      NotificationEntity(
        id: 'fallback-1',
        title: 'Fallback',
        message: 'Schedule path',
        scheduledAt: DateTime.utc(2099, 1, 1),
      ),
    );
    await fallbackRepository.cancelNotification('fallback-1');
    await fallbackRepository.delete('fallback-1');
    await fallbackRepository.cancelAll();

    final stored = await fallbackRepository.getNotifications();
    expect(stored, isEmpty);
  });

  test('exception paths during schedule/cancel/delete/cancelAll do not lose storage', () async {
    final throwingRepository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: InMemorySecureStoreBackend()),
      scheduleNotification: (NotificationEntity _) async {
        throw Exception('schedule failed');
      },
      cancelScheduledNotification: (String _) async {
        throw Exception('cancel failed');
      },
      cancelAllScheduledNotifications: () async {
        throw Exception('cancel all failed');
      },
    );

    await Logger.withMutedErrors(() async {
      await throwingRepository.scheduleNotification(
        NotificationEntity(
          id: 'throw-1',
          title: 'Throwing',
          message: 'Still persist',
          scheduledAt: DateTime.utc(2026, 7, 5, 16),
        ),
      );
      await throwingRepository.cancelNotification('throw-1');
      await throwingRepository.delete('throw-1');
      await throwingRepository.cancelAll();
    });

    expect(await throwingRepository.getNotifications(), isEmpty);
  });
}
