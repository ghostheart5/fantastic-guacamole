import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/policies/notification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPolicy', () {
    final now = DateTime.utc(2026, 7, 5, 12, 0);

    test('canSchedule returns true for enabled notification in the future', () {
      final notification = NotificationEntity(
        id: 'n1',
        title: 'Reminder',
        message: 'Start session',
        scheduledAt: now.add(const Duration(minutes: 1)),
      );

      expect(NotificationPolicy.canSchedule(notification, now: now), isTrue);
    });

    test('canSchedule returns false for disabled notification', () {
      final notification = NotificationEntity(
        id: 'n2',
        title: 'Disabled',
        message: 'Do not send',
        scheduledAt: now.add(const Duration(minutes: 10)),
        isEnabled: false,
      );

      expect(NotificationPolicy.canSchedule(notification, now: now), isFalse);
    });

    test('canSchedule returns false when scheduledAt is now or in the past', () {
      final atNow = NotificationEntity(
        id: 'n3',
        title: 'Now',
        message: 'Edge case',
        scheduledAt: now,
      );
      final inPast = NotificationEntity(
        id: 'n4',
        title: 'Past',
        message: 'Too late',
        scheduledAt: now.subtract(const Duration(seconds: 1)),
      );

      expect(NotificationPolicy.canSchedule(atNow, now: now), isFalse);
      expect(NotificationPolicy.canSchedule(inPast, now: now), isFalse);
    });

    test('canSchedule uses current time when now argument is omitted', () {
      final notification = NotificationEntity(
        id: 'n5',
        title: 'Implicit now branch',
        message: 'Cover branch',
        scheduledAt: DateTime.now().add(const Duration(minutes: 2)),
      );

      expect(NotificationPolicy.canSchedule(notification), isTrue);
    });

    test('blocks spammy repeated notifications', () {
      final recent = <NotificationEntity>[
        NotificationEntity(
          id: 's1',
          title: 'Hydrate',
          message: 'Drink water',
          scheduledAt: now.subtract(const Duration(minutes: 5)),
        ),
      ];
      final candidate = NotificationEntity(
        id: 's2',
        title: 'Hydrate',
        message: 'Drink water',
        scheduledAt: now,
      );

      expect(
        NotificationPolicy.canDispatch(
          candidate,
          now: now,
          recentlySent: recent,
          cooldown: const Duration(minutes: 1),
          repeatWindow: const Duration(minutes: 30),
        ),
        isFalse,
      );
    });

    test('allows high-priority reminders', () {
      final recent = <NotificationEntity>[
        NotificationEntity(
          id: 'p1',
          title: 'Hydrate',
          message: 'Drink water',
          scheduledAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];
      final candidate = NotificationEntity(
        id: 'p2',
        title: 'Critical deadline',
        message: 'Submit before cutoff',
        scheduledAt: now,
      );

      expect(
        NotificationPolicy.canDispatch(
          candidate,
          now: now,
          recentlySent: recent,
          isHighPriority: true,
        ),
        isTrue,
      );
    });

    test('respects cooldown', () {
      final recent = <NotificationEntity>[
        NotificationEntity(
          id: 'c1',
          title: 'Recent',
          message: 'Recent ping',
          scheduledAt: now.subtract(const Duration(minutes: 2)),
        ),
      ];
      final candidate = NotificationEntity(
        id: 'c2',
        title: 'Another ping',
        message: 'Too soon',
        scheduledAt: now,
      );

      expect(
        NotificationPolicy.canDispatch(
          candidate,
          now: now,
          recentlySent: recent,
          cooldown: const Duration(minutes: 5),
        ),
        isFalse,
      );
    });

    test('handles permission-disabled state', () {
      final candidate = NotificationEntity(
        id: 'perm-1',
        title: 'Reminder',
        message: 'Permission off',
        scheduledAt: now,
      );

      expect(
        NotificationPolicy.canDispatch(
          candidate,
          now: now,
          recentlySent: const <NotificationEntity>[],
          permissionEnabled: false,
        ),
        isFalse,
      );
    });
  });
}
