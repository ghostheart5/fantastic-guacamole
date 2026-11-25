import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notifications surface had no widget coverage. Both the empty state and
/// the populated list are first-run-visible, so both are pinned here.
void main() {
  Future<ProviderContainer> pumpNotifications(
    WidgetTester tester,
    List<NotificationEntity> items, {
    List<NotificationEntity> repeating = const [],
    Locale locale = const Locale('en'),
    RegisteredReminders registered = const RegisteredReminders(
      ids: <String>{},
      permissionGranted: true,
    ),
    bool osListPending = false,
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
        registeredRemindersProvider.overrideWith(
          (ref) => osListPending
              ? Completer<RegisteredReminders>().future
              : Future<RegisteredReminders>.value(registered),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const NotificationsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
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

  for (final (locale, title, message) in [
    (const Locale('en'), 'Goal completed', '"Run a 5K" is complete.'),
    (const Locale('es'), 'Meta completada', '"Run a 5K" se cumplió.'),
  ]) {
    testWidgets('a completed goal entry reads "$title"', (tester) async {
      await pumpNotifications(tester, <NotificationEntity>[
        NotificationEntity(
          id: 'notification-1',
          title: 'Goal completed',
          message: '"Run a 5K" is complete.',
          scheduledAt: DateTime.utc(2026, 8, 6, 22),
          isEnabled: false,
        ),
      ], locale: locale);

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  // Records written in English before the app switched to Spanish are
  // translated with the text the app generates today.
  for (final (rawTitle, rawMessage, title, message) in [
    (
      'Goal due tomorrow',
      '"Trip" is due tomorrow. 1 of 3 steps done.',
      'Meta para mañana',
      '«Trip» vence mañana. 1 de 3 pasos hechos.',
    ),
    (
      'Goal due tomorrow',
      '"Trip" is due tomorrow.',
      'Meta para mañana',
      '«Trip» vence mañana.',
    ),
    (
      'Task Skipped',
      'Stretch skipped. SI will adapt the next pick.',
      'Tarea omitida',
      'Stretch se omitió. SI adaptará la próxima elección.',
    ),
  ]) {
    testWidgets('an English "$rawMessage" record reads in Spanish', (
      tester,
    ) async {
      await pumpNotifications(tester, <NotificationEntity>[
        NotificationEntity(
          id: 'notification-es',
          title: rawTitle,
          message: rawMessage,
          scheduledAt: DateTime.utc(2026, 8, 6, 22),
          isEnabled: false,
        ),
      ], locale: const Locale('es'));

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  NotificationEntity goalDueTomorrow({
    NotificationScheduleResult? result,
    bool enabled = true,
    String id = 'goal_reminder_trip',
  }) => NotificationEntity(
    id: id,
    title: 'Goal due tomorrow',
    message: '"Trip" is due tomorrow.',
    scheduledAt: DateTime.now().add(const Duration(days: 2)),
    isEnabled: enabled,
    scheduleResult: result,
  );

  for (final (locale, label) in [
    (const Locale('en'), 'Not scheduled: notifications are off'),
    (
      const Locale('es'),
      'No programado: las notificaciones están desactivadas',
    ),
  ]) {
    testWidgets('a refused reminder reads "$label", not Scheduled', (
      tester,
    ) async {
      await pumpNotifications(
        tester,
        <NotificationEntity>[
          goalDueTomorrow(result: NotificationScheduleResult.permissionDenied),
        ],
        locale: locale,
        registered: const RegisteredReminders(
          ids: <String>{},
          permissionGranted: false,
        ),
      );

      expect(find.textContaining(label), findsOneWidget);
      expect(find.textContaining('Scheduled ·'), findsNothing);
      expect(find.textContaining('Programado ·'), findsNothing);
      expect(
        find.textContaining(
          locale.languageCode == 'es' ? '0 programadas' : '0 scheduled',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final (result, label) in [
    (
      NotificationScheduleResult.unsupported,
      'Not scheduled: not available on this device',
    ),
    (NotificationScheduleResult.failed, 'Not scheduled: could not be set'),
  ]) {
    testWidgets('a ${result.name} reminder reads "$label"', (tester) async {
      await pumpNotifications(tester, <NotificationEntity>[
        goalDueTomorrow(result: result),
      ]);

      expect(find.textContaining(label), findsOneWidget);
      expect(find.textContaining('Scheduled ·'), findsNothing);
    });
  }

  testWidgets('a reminder the OS no longer holds is not shown as Scheduled', (
    tester,
  ) async {
    // Accepted once, then cleared by the reminder updater while
    // notifications were off: the stored result alone would still say
    // scheduled.
    await pumpNotifications(
      tester,
      <NotificationEntity>[
        goalDueTomorrow(result: NotificationScheduleResult.scheduled),
      ],
      registered: const RegisteredReminders(
        ids: <String>{},
        permissionGranted: false,
      ),
    );

    expect(
      find.textContaining('Not scheduled: notifications are off'),
      findsOneWidget,
    );
    expect(find.textContaining('Scheduled ·'), findsNothing);
  });

  testWidgets('a reminder the OS holds reads Scheduled', (tester) async {
    await pumpNotifications(
      tester,
      <NotificationEntity>[
        goalDueTomorrow(result: NotificationScheduleResult.scheduled),
      ],
      registered: const RegisteredReminders(
        ids: <String>{'goal_reminder_trip'},
        permissionGranted: true,
      ),
    );

    expect(find.textContaining('Scheduled ·'), findsOneWidget);
    expect(find.textContaining('Not scheduled'), findsNothing);
    expect(find.textContaining('1 scheduled'), findsOneWidget);
  });

  testWidgets(
    'the badge counts what the screen counts as new, with a future and a cancelled reminder present',
    (tester) async {
      final ProviderContainer container = await pumpNotifications(
        tester,
        <NotificationEntity>[
          NotificationEntity(
            id: 'goal_reminder_past',
            title: 'Delivered reminder',
            message: 'Already went off.',
            scheduledAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          NotificationEntity(
            id: 'notification-1',
            title: 'Goal completed',
            message: '"Run a 5K" is complete.',
            scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
            isEnabled: false,
          ),
          goalDueTomorrow(result: NotificationScheduleResult.scheduled),
          NotificationEntity(
            id: 'goal_reminder_switched_off',
            title: 'Switched off reminder',
            message: 'Cancelled by an older build.',
            scheduledAt: DateTime.now().add(const Duration(days: 3)),
            isEnabled: false,
          ),
        ],
        registered: const RegisteredReminders(
          ids: <String>{'goal_reminder_trip'},
          permissionGranted: true,
        ),
      );

      expect(find.textContaining('2 new'), findsOneWidget);
      expect(container.read(unreadNotificationsProvider), 2);
      expect(find.text('Switched off reminder'), findsNothing);
      expect(find.textContaining('3 total'), findsOneWidget);
    },
  );
  testWidgets(
    'reminders that already went off read as past activity and count as new',
    (tester) async {
      final ProviderContainer container = await pumpNotifications(
        tester,
        <NotificationEntity>[
          // Went off this morning; the OS no longer holds it.
          NotificationEntity(
            id: 'goal_reminder_trip',
            title: 'Goal due tomorrow',
            message: '"Trip" is due tomorrow.',
            scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
            scheduleResult: NotificationScheduleResult.scheduled,
          ),
          // An older build disabled it after it went off.
          NotificationEntity(
            id: 'goal_reminder_old',
            title: 'Goal coming up',
            message: '"Old" is due in 3 days.',
            scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
            isEnabled: false,
          ),
        ],
        registered: const RegisteredReminders(
          ids: <String>{},
          permissionGranted: false,
        ),
      );

      expect(find.text('Goal due tomorrow'), findsOneWidget);
      expect(find.text('Goal coming up'), findsOneWidget);
      expect(find.textContaining('Scheduled time ·'), findsNWidgets(2));
      expect(find.textContaining('Not scheduled'), findsNothing);
      expect(find.textContaining('Scheduled ·'), findsNothing);
      expect(find.textContaining('2 new'), findsOneWidget);
      expect(container.read(unreadNotificationsProvider), 2);
    },
  );

  for (final (locale, visible, spoken, wrong) in [
    (
      const Locale('en'),
      'Scheduled time ·',
      'Reminder, scheduled time: Goal due tomorrow',
      'Scheduled reminder: Goal due tomorrow',
    ),
    (
      const Locale('es'),
      'Hora prevista ·',
      'Recordatorio, hora prevista: Meta para mañana',
      'Recordatorio programado: Meta para mañana',
    ),
  ]) {
    testWidgets(
      'an unconfirmed reminder is announced as "$spoken", like its label',
      (tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await pumpNotifications(
          tester,
          <NotificationEntity>[goalDueTomorrow()],
          locale: locale,
          osListPending: true,
        );

        expect(find.textContaining(visible), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(spoken)}')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(wrong)}')),
          findsNothing,
        );
        semantics.dispose();
      },
    );
  }
}

class _StaticNotifications extends NotificationNotifier {
  _StaticNotifications(this._items);

  final List<NotificationEntity> _items;

  @override
  List<NotificationEntity> build() => _items;
}
