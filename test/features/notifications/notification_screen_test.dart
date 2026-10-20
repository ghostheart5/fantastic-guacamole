import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notifications surface had no widget coverage. Both the empty state and
/// the populated list are first-run-visible, so both are pinned here.
void main() {
  Future<void> pumpNotifications(
    WidgetTester tester,
    List<NotificationEntity> items, {
    List<NotificationEntity> repeating = const [],
  }) async {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        notificationProvider.overrideWith(() => _StaticNotifications(items)),
        automationNotificationsProvider.overrideWith((ref) async => repeating),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'native daily registrations appear without one-shot rescheduling',
    (tester) async {
      await pumpNotifications(
        tester,
        const [],
        repeating: [
          NotificationEntity(
            id: 'daily_planning_reminder',
            title: 'Daily Planning Reminder',
            message: 'Plan your day',
            scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ],
      );
      await tester.pump();
      expect(find.text('Daily Planning Reminder'), findsOneWidget);
      expect(find.textContaining('1 scheduled'), findsOneWidget);
      expect(find.text('NO ALERTS'), findsNothing);
      expect(
        find.textContaining('Manage this repeating reminder in Settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy registration does not claim its configured time is registered',
    (tester) async {
      await pumpNotifications(
        tester,
        const [],
        repeating: [
          AutomationNotification(
            id: 'daily_planning_reminder',
            title: 'Legacy daily reminder',
            message: 'Plan',
            scheduledAt: DateTime(2026, 10, 12, 7, 30),
            registeredTimeKnown: false,
          ),
        ],
      );
      await tester.pump();
      expect(
        find.textContaining('Configured time; registered time unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('Next daily time'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows a reassuring empty state when there is nothing pending', (
    WidgetTester tester,
  ) async {
    await pumpNotifications(tester, const <NotificationEntity>[]);

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('NO ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders scheduled notifications', (WidgetTester tester) async {
    await pumpNotifications(tester, <NotificationEntity>[
      NotificationEntity(
        id: 'n-1',
        title: 'Daily reflection',
        message: 'Take two minutes to review today.',
        scheduledAt: DateTime.utc(2026, 8, 6, 20),
      ),
      NotificationEntity(
        id: 'n-2',
        title: 'Plan tomorrow',
        message: 'Set one priority for the morning.',
        scheduledAt: DateTime.utc(2026, 8, 6, 21),
        isRead: true,
      ),
    ]);

    expect(find.text('Daily reflection'), findsOneWidget);
    expect(find.text('Plan tomorrow'), findsOneWidget);
    expect(find.text('NO ALERTS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a disabled notification without crashing', (
    WidgetTester tester,
  ) async {
    // Cancelling a notification disables the record rather than deleting it,
    // so the disabled variant is a real state this list has to render.
    await pumpNotifications(tester, <NotificationEntity>[
      NotificationEntity(
        id: 'n-3',
        title: 'Cancelled reminder',
        message: 'This one was switched off.',
        scheduledAt: DateTime.utc(2026, 8, 6, 22),
        isEnabled: false,
      ),
    ]);

    expect(find.text('Cancelled reminder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StaticNotifications extends NotificationNotifier {
  _StaticNotifications(this._items);

  final List<NotificationEntity> _items;

  @override
  List<NotificationEntity> build() => _items;
}
