import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_permission_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../permissions/notification_permission_test_support.dart';

const Key _inactive = ValueKey<String>('rhythm-reminder-inactive-walk');
const Key _action = ValueKey<String>('rhythm-reminder-inactive-action-walk');
const Key _label = ValueKey<String>('rhythm-reminder-label-walk');

Future<PermissionFixture> _open(
  WidgetTester tester, {
  required bool granted,
  bool remindersOn = true,
  bool habitRemindersOn = true,
  bool spanish = false,
  double textScale = 1,
  Size size = const Size(500, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late PermissionFixture fixture;
  fixture = PermissionFixture(
    overrides: [
      domainHabitRepositoryProvider.overrideWithValue(_Habits()),
      habitOccurrencesProvider.overrideWith(
        (ref) async => const <HabitOccurrenceEntity>[],
      ),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      reminderOrchestratorServiceProvider.overrideWith(
        (ref) => ReminderOrchestratorService(
          preferences: ref.watch(accountSharedPrefsStoreProvider),
          notifications: NotificationsService(_Notifications()),
          scheduler: fixture.scheduler,
          accountScope: 'qa',
          loadHabitOccurrences: () async => const <HabitOccurrenceEntity>[],
          timeZoneName: () => 'Etc/UTC',
        ),
      ),
      notificationPermissionSupportedProvider.overrideWithValue(true),
    ],
  );
  fixture.scheduler.granted = granted;
  fixture.scheduler.signal.value = granted;
  fixture.actions.reminderPrefs = ReminderOrchestratorPrefs(
    goalRemindersEnabled: true,
    habitRemindersEnabled: habitRemindersOn,
    dailyPlanningEnabled: true,
    dailyPlanningHour: 7,
    dailyPlanningMinute: 30,
    remindersEnabled: remindersOn,
  );
  await tester.pumpWidget(
    fixture.app(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const DailyRhythmsScreen(),
        ),
      ),
      spanish: spanish,
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  for (final spanish in <bool>[false, true]) {
    final String lang = spanish ? 'es' : 'en';

    testWidgets('[$lang] a reminder that can arrive looks normal', (
      tester,
    ) async {
      await _open(tester, granted: true, spanish: spanish);
      expect(find.byKey(_label), findsOneWidget);
      expect(find.byKey(_inactive), findsNothing);
    });

    testWidgets('[$lang] notifications off: inactive line, reason and an '
        'action that runs the permission flow', (tester) async {
      await _open(tester, granted: false, spanish: spanish);
      expect(
        find.descendant(
          of: find.byKey(_inactive),
          matching: find.text(
            spanish
                ? 'Las notificaciones están desactivadas'
                : 'Notifications are off',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_label), findsOneWidget);
      expect(
        tester.getSize(find.byKey(_action)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.ensureVisible(find.byKey(_action));
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      // The explanation comes before the system dialog.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('[$lang] the main Reminders switch off: inactive line and an '
        'action that opens Settings', (tester) async {
      await _open(tester, granted: true, remindersOn: false, spanish: spanish);
      expect(
        find.descendant(
          of: find.byKey(_inactive),
          matching: find.text(
            spanish
                ? 'Los recordatorios están desactivados'
                : 'Reminders are off',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_action),
          matching: find.text(spanish ? 'Abrir ajustes' : 'Open settings'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('[$lang] the habit reminders switch off is also a reason', (
      tester,
    ) async {
      await _open(
        tester,
        granted: true,
        habitRemindersOn: false,
        spanish: spanish,
      );
      expect(
        find.descendant(
          of: find.byKey(_inactive),
          matching: find.text(
            spanish
                ? 'Los recordatorios de hábitos están desactivados'
                : 'Habit reminders are off',
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('after a system refusal the action sends the person to device '
      'settings', (tester) async {
    final fixture = await _open(tester, granted: false);
    await fixture.container
        .read(notificationPermissionProvider.notifier)
        .request(via: () async => false);
    await tester.ensureVisible(find.byKey(_action));
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(fixture.actions.settingsOpened, 1);
  });

  testWidgets('the line goes back to normal when permission returns, without '
      'leaving the screen', (tester) async {
    final fixture = await _open(tester, granted: false);
    expect(find.byKey(_inactive), findsOneWidget);
    fixture.scheduler.signal.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(_inactive), findsNothing);
    expect(find.byKey(_label), findsOneWidget);
  });

  testWidgets('no overflow at text scale 2.0 on a 320 dp screen', (
    tester,
  ) async {
    await _open(
      tester,
      granted: false,
      textScale: 2,
      size: const Size(320, 1600),
    );
    expect(find.byKey(_inactive), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Habits implements IHabitRepository {
  final List<HabitEntity> saved = <HabitEntity>[
    HabitEntity(
      id: 'walk',
      title: 'Evening walk',
      createdAt: DateTime(2026, 9, 1),
      reminderMinutes: 17 * 60,
    ),
  ];

  @override
  Future<List<HabitEntity>> getHabits() async => List.of(saved);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}

class _Notifications implements INotificationRepository {
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
