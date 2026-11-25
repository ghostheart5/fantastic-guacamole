import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
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
      accountId: 'account-a',
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

  test(
    'scheduleNotification persists and keeps most recent value by id',
    () async {
      final now = DateTime.utc(2026, 7, 5, 10);
      await repository.scheduleNotification(
        NotificationEntity(
          id: 'n-1',
          title: 'First',
          message: 'A',
          scheduledAt: now,
        ),
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
    },
  );

  test(
    'returns empty notifications when persisted storage is corrupt',
    () async {
      await SecureStore(backend: backend).writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-a'),
        '{not-json',
      );

      final List<NotificationEntity> entries = await Logger.withMutedErrors(
        () => repository.getNotifications(),
      );

      expect(entries, isEmpty);
    },
  );

  test('skips malformed map items and keeps valid notifications', () async {
    await SecureStore(backend: backend).writeString(
      AccountDataRegistry.notificationSecureKeyFor('account-a'),
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

  test('cancelling a reminder removes its stored record', () async {
    await repository.scheduleNotification(
      NotificationEntity(
        id: 'goal_reminder_trip',
        title: 'Goal due tomorrow',
        message: 'Book the trip',
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      ),
    );

    await repository.cancelNotification('goal_reminder_trip');

    expect(cancelledIds, <String>['goal_reminder_trip']);
    expect(await repository.getNotifications(), isEmpty);
  });

  test('cancelling leaves an in-app history entry as it was', () async {
    final NotificationEntity history = NotificationEntity(
      id: 'notification-1',
      title: 'Goal completed',
      message: '"Trip" is complete.',
      scheduledAt: DateTime.utc(2026, 7, 5, 11),
      isEnabled: false,
    );
    await repository.scheduleNotification(history);

    await repository.cancelNotification(history.id);

    final NotificationEntity stored =
        (await repository.getNotifications()).single;
    expect(stored.id, history.id);
    expect(stored.isEnabled, isFalse);
    expect(stored.isRead, isFalse);
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

  NotificationEntity reminder({
    String title = 'Goal Reminder',
    String message = 'Prepare Thursday grocery pickup',
    DateTime? at,
    bool enabled = true,
  }) => NotificationEntity(
    id: 'goal_reminder_groceries',
    title: title,
    message: message,
    scheduledAt: at ?? DateTime.utc(2026, 9, 16),
    isEnabled: enabled,
  );

  NotificationsRepository reopen({
    String accountId = 'account-a',
    Future<void> Function(NotificationEntity)? schedule,
  }) => NotificationsRepository(
    NotificationScheduler(),
    SecureStore(backend: backend),
    accountId: accountId,
    scheduleNotification: schedule ?? (_) async {},
  );

  test(
    'unchanged reminder stays read across repeated scheduling and reload',
    () async {
      await repository.scheduleNotification(reminder());
      await repository.markRead(reminder().id);
      final scheduled = <NotificationEntity>[];
      final reopened = reopen(schedule: (entry) async => scheduled.add(entry));

      await reopened.scheduleNotification(reminder());
      await reopened.scheduleNotification(reminder());

      final persisted = await reopen().getNotifications();
      expect(persisted, hasLength(1));
      expect(persisted.single.isRead, isTrue);
      expect(scheduled, hasLength(2));
      expect(scheduled.every((entry) => entry.isRead), isTrue);
    },
  );

  for (final field in ['title', 'message', 'time']) {
    test('changed reminder $field is unread even with the same ID', () async {
      await repository.scheduleNotification(reminder());
      await repository.markRead(reminder().id);
      final changed = reminder(
        title: field == 'title' ? 'Updated goal reminder' : 'Goal Reminder',
        message: field == 'message'
            ? 'Prepare Friday grocery pickup'
            : 'Prepare Thursday grocery pickup',
        at: field == 'time' ? DateTime.utc(2026, 9, 17) : null,
      );

      await reopen().scheduleNotification(changed);

      final persisted = await reopen().getNotifications();
      expect(persisted, hasLength(1));
      expect(persisted.single.isRead, isFalse);
      expect(persisted.single.title, changed.title);
      expect(persisted.single.message, changed.message);
      expect(
        persisted.single.scheduledAt.isAtSameMomentAs(changed.scheduledAt),
        isTrue,
      );
    });
  }

  test(
    'equivalent local and UTC instants preserve reminder read state',
    () async {
      final instant = DateTime.utc(2026, 9, 16);
      await repository.scheduleNotification(reminder(at: instant.toLocal()));
      await repository.markRead(reminder().id);

      await reopen().scheduleNotification(reminder(at: instant));

      expect((await reopen().getNotifications()).single.isRead, isTrue);
    },
  );

  test(
    'a cancelled reminder scheduled again comes back as a new record',
    () async {
      await repository.scheduleNotification(reminder());
      await repository.markRead(reminder().id);
      await repository.cancelNotification(reminder().id);
      expect(await repository.getNotifications(), isEmpty);

      await reopen().scheduleNotification(reminder());

      final persisted = (await reopen().getNotifications()).single;
      expect(persisted.isEnabled, isTrue);
      expect(persisted.isRead, isFalse);
    },
  );

  for (final NotificationScheduleResult refused in <NotificationScheduleResult>[
    NotificationScheduleResult.permissionDenied,
    NotificationScheduleResult.unsupported,
    NotificationScheduleResult.failed,
  ]) {
    test(
      'a refused schedule is stored with its reason (${refused.name})',
      () async {
        final NotificationsRepository refusing = NotificationsRepository(
          _ResultScheduler(refused),
          SecureStore(backend: backend),
          accountId: 'account-a',
        );

        await refusing.scheduleNotification(reminder(at: DateTime(2099)));

        expect(
          (await reopen().getNotifications()).single.scheduleResult,
          refused,
        );
      },
    );
  }

  test('an accepted schedule is stored as scheduled', () async {
    final NotificationsRepository accepting = NotificationsRepository(
      _ResultScheduler(NotificationScheduleResult.scheduled),
      SecureStore(backend: backend),
      accountId: 'account-a',
    );

    await accepting.scheduleNotification(reminder(at: DateTime(2099)));

    expect(
      (await reopen().getNotifications()).single.scheduleResult,
      NotificationScheduleResult.scheduled,
    );
  });

  test('a scheduler error is stored as failed and logged', () async {
    final NotificationsRepository throwing = NotificationsRepository(
      _ResultScheduler(null),
      SecureStore(backend: backend),
      accountId: 'account-a',
    );

    await Logger.withMutedErrors(
      () => throwing.scheduleNotification(reminder(at: DateTime(2099))),
    );

    expect(
      (await reopen().getNotifications()).single.scheduleResult,
      NotificationScheduleResult.failed,
    );
  });

  test(
    'old stored lists still load and stale cancelled reminders are hidden',
    () async {
      final DateTime future = DateTime.now().add(const Duration(days: 3));
      Map<String, Object?> row(
        String id, {
        required bool enabled,
        DateTime? at,
      }) => <String, Object?>{
        'id': id,
        'title': id,
        'message': 'Stored before scheduleResult existed',
        'scheduledAt': (at ?? DateTime.utc(2026, 7, 5))
            .toUtc()
            .toIso8601String(),
        'isEnabled': enabled,
        'isRead': false,
      };
      await SecureStore(backend: backend).writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-a'),
        jsonEncode(<Map<String, Object?>>[
          row('goal_reminder_live', enabled: true, at: future),
          row('goal_reminder_cancelled', enabled: false, at: future),
          row('notification-42', enabled: false),
          <String, Object?>{
            ...row('goal_reminder_odd', enabled: true, at: future),
            'scheduleResult': 'somethingNew',
          },
        ]),
      );

      final List<NotificationEntity> entries = await repository
          .getNotifications();

      expect(
        entries.map((NotificationEntity entry) => entry.id).toSet(),
        <String>{'goal_reminder_live', 'notification-42', 'goal_reminder_odd'},
      );
      expect(
        entries.every(
          (NotificationEntity entry) => entry.scheduleResult == null,
        ),
        isTrue,
      );

      // The next write drops the stale row for good.
      await repository.markRead('notification-42');
      final String? raw = await SecureStore(
        backend: backend,
      ).readString(AccountDataRegistry.notificationSecureKeyFor('account-a'));
      expect(raw, isNot(contains('goal_reminder_cancelled')));
    },
  );

  test('same reminder ID cannot inherit another account read state', () async {
    await repository.scheduleNotification(reminder());
    await repository.markRead(reminder().id);
    final otherAccount = reopen(accountId: 'account-b');

    await otherAccount.scheduleNotification(reminder());
    await reopen().scheduleNotification(reminder());

    expect((await reopen().getNotifications()).single.isRead, isTrue);
    expect((await otherAccount.getNotifications()).single.isRead, isFalse);
  });

  for (final readFirst in [true, false]) {
    test(
      'concurrent read and reminder sync preserve read state (read first: $readFirst)',
      () async {
        await repository.scheduleNotification(reminder());
        final otherInstance = reopen();
        await Future.wait<void>([
          if (readFirst) repository.markRead(reminder().id),
          otherInstance.scheduleNotification(reminder()),
          if (!readFirst) repository.markRead(reminder().id),
        ]);

        final persisted = await reopen().getNotifications();
        expect(persisted, hasLength(1));
        expect(persisted.single.isRead, isTrue);
      },
    );
  }

  test(
    'cancelAll disables all notifications and invokes scheduler hook',
    () async {
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
    },
  );

  test(
    'cancelNotification and markRead are safe no-ops when id is missing',
    () async {
      await repository.cancelNotification('missing');
      await repository.markRead('missing');

      expect(await repository.getNotifications(), isEmpty);
      expect(cancelledIds, <String>['missing']);
    },
  );

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
      accountId: 'account-a',
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

  test(
    'exception paths during schedule/cancel/delete/cancelAll do not lose storage',
    () async {
      final throwingRepository = NotificationsRepository(
        NotificationScheduler(),
        SecureStore(backend: InMemorySecureStoreBackend()),
        accountId: 'account-a',
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
    },
  );

  test('account repositories cannot read or overwrite each other', () async {
    final SecureStore store = SecureStore(backend: backend);
    final NotificationsRepository accountB = NotificationsRepository(
      NotificationScheduler(),
      store,
      accountId: 'account-b',
      scheduleNotification: (_) async {},
    );

    await repository.scheduleNotification(
      NotificationEntity(
        id: 'a-only',
        title: 'A',
        message: 'Private A notification',
        scheduledAt: DateTime.utc(2026, 7, 5, 17),
      ),
    );
    await accountB.scheduleNotification(
      NotificationEntity(
        id: 'b-only',
        title: 'B',
        message: 'Private B notification',
        scheduledAt: DateTime.utc(2026, 7, 5, 18),
      ),
    );

    expect((await repository.getNotifications()).single.id, 'a-only');
    expect((await accountB.getNotifications()).single.id, 'b-only');
  });

  test('signed-out repository fails closed', () async {
    final NotificationsRepository signedOut = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: backend),
    );

    await signedOut.scheduleNotification(
      NotificationEntity(
        id: 'ignored',
        title: 'Ignored',
        message: 'No owner',
        scheduledAt: DateTime.utc(2026, 7, 5, 19),
      ),
    );

    expect(await signedOut.getNotifications(), isEmpty);
  });

  test('concurrent repository instances preserve both mutations', () async {
    final SecureStore store = SecureStore(backend: backend);
    final NotificationsRepository second = NotificationsRepository(
      NotificationScheduler(),
      store,
      accountId: 'account-a',
      scheduleNotification: (_) async {},
    );

    await Future.wait(<Future<void>>[
      repository.scheduleNotification(
        NotificationEntity(
          id: 'first',
          title: 'First',
          message: 'First',
          scheduledAt: DateTime.utc(2026, 7, 5, 20),
        ),
      ),
      second.scheduleNotification(
        NotificationEntity(
          id: 'second',
          title: 'Second',
          message: 'Second',
          scheduledAt: DateTime.utc(2026, 7, 5, 21),
        ),
      ),
    ]);

    expect(await repository.getNotifications(), hasLength(2));
  });
}

/// Answers every one-off schedule with [result], or throws when it is null.
class _ResultScheduler implements NotificationSchedulerPort {
  _ResultScheduler(this.result);

  final NotificationScheduleResult? result;

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    final NotificationScheduleResult? value = result;
    if (value == null) throw StateError('platform refused');
    return value;
  }

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => NotificationScheduleResult.unsupported;

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => NotificationScheduleResult.unsupported;

  @override
  Future<bool> cancel(String id, {String? accountScope}) async => true;

  @override
  Future<bool> cancelAll() async => true;

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      const <String>[];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  void clearTappedPayload() {}
}
