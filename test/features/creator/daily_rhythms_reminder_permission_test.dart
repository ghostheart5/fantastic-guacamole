import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../permissions/notification_permission_test_support.dart';

void main() {
  for (final denied in <bool>[true, false]) {
    testWidgets(
      'setting a habit reminder with permission ${denied ? 'off' : 'on'} '
      'saves without a reminder error${denied ? ', then asks' : ''}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final habits = _Habits();
        late PermissionFixture fixture;
        fixture = PermissionFixture(
          overrides: [
            domainHabitRepositoryProvider.overrideWithValue(habits),
            habitOccurrencesProvider.overrideWith(
              (ref) async => const <HabitOccurrenceEntity>[],
            ),
            secureStoreProvider.overrideWithValue(
              SecureStore(backend: InMemorySecureStoreBackend()),
            ),
            // The real reminder sync, on a device whose permission is off.
            reminderOrchestratorServiceProvider.overrideWith(
              (ref) => ReminderOrchestratorService(
                preferences: ref.watch(accountSharedPrefsStoreProvider),
                notifications: NotificationsService(_Notifications()),
                scheduler: fixture.scheduler,
                accountScope: 'qa',
                loadHabitOccurrences: () async =>
                    const <HabitOccurrenceEntity>[],
                timeZoneName: () => 'Etc/UTC',
              ),
            ),
          ],
        );
        fixture.scheduler.granted = !denied;
        await tester.pumpWidget(
          fixture.app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const DailyRhythmsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (find.text('Set reminder').evaluate().isEmpty) {
          await tester.tap(find.text('Habit options'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Set reminder'));
        await tester.tap(find.text('Set reminder'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(habits.saved.single.reminderMinutes, 17 * 60);
        expect(
          find.text('Your change was saved, but reminders could not update.'),
          findsNothing,
        );
        expect(find.textContaining('Could not save'), findsNothing);
        expect(
          find.text('WHEN IT IS USED'),
          denied ? findsOneWidget : findsNothing,
        );
        expect(fixture.actions.requests, 0);
      },
    );
  }

  testWidgets('a weekly habit reminder asks which days and the card states '
      'them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final habits = _Habits(cadence: HabitCadence.weekly);
    late PermissionFixture fixture;
    fixture = PermissionFixture(
      overrides: [
        domainHabitRepositoryProvider.overrideWithValue(habits),
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
      ],
    );
    fixture.scheduler.granted = true;
    await tester.pumpWidget(
      fixture.app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const DailyRhythmsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> openReminder(String label) async {
      if (find.text(label).hitTestable().evaluate().isEmpty) {
        await tester.tap(find.text('Habit options'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await openReminder('Set reminder');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Monday is chosen to start with; swap it for Wednesday and Friday.
    for (final day in [3, 1, 5]) {
      await tester.tap(
        find.byKey(ValueKey<String>('habit-reminder-weekday-$day')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(habits.saved.single.reminderMinutes, 17 * 60);
    expect(habits.saved.single.reminderWeekdays, [3, 5]);
    String cardLabel() => tester
        .widget<Text>(find.byKey(const ValueKey('rhythm-reminder-label-walk')))
        .data!;
    expect(cardLabel(), 'Reminder: 5:00 PM every Wednesday and Friday');

    // The days can be changed later without touching the time.
    await openReminder('Reminder');
    await tester.tap(find.text('Change days'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('habit-reminder-weekday-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(habits.saved.single.reminderWeekdays, [5]);
    expect(habits.saved.single.reminderMinutes, 17 * 60);
    expect(cardLabel(), 'Reminder: 5:00 PM every Friday');
  });
}

class _Habits implements IHabitRepository {
  _Habits({HabitCadence cadence = HabitCadence.daily})
    : saved = <HabitEntity>[
        HabitEntity(
          id: 'walk',
          title: 'Evening walk',
          createdAt: DateTime(2026, 9, 1),
          cadence: cadence,
        ),
      ];

  List<HabitEntity> saved;

  @override
  Future<List<HabitEntity>> getHabits() async => List.of(saved);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    saved = List.of(habits);
  }
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
