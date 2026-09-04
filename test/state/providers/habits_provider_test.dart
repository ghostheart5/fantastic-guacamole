import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'daily rhythm notifier persists create, toggle, rename, and remove',
    () async {
      final DateTime now = DateTime.utc(2026, 9, 3, 12);
      final _FakeHabitRepository repository = _FakeHabitRepository(
        <HabitEntity>[HabitEntity(id: 'walk', title: 'Walk', createdAt: now)],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            const AccountStorageScope.signedOut(),
          ),
          domainHabitRepositoryProvider.overrideWithValue(repository),
          reminderOrchestratorServiceProvider.overrideWithValue(
            ReminderOrchestratorService(
              preferences: _DisabledPreferences(),
              notifications: NotificationsService(_NoopNotifications()),
              scheduler: NotificationScheduler(),
              accountScope: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(habitsProvider.future);

      final HabitsNotifier notifier = container.read(habitsProvider.notifier);
      expect(container.read(habitProvider).requireValue.single.title, 'Walk');

      await notifier.addHabit(title: '  Journal  ');
      expect(
        container.read(habitsProvider).requireValue.first.title,
        'Journal',
      );
      final int afterAdd = repository.saveCalls;
      await notifier.addHabit(title: '   ');
      expect(repository.saveCalls, afterAdd);

      await notifier.toggleHabit('walk');
      expect(
        container
            .read(habitsProvider)
            .requireValue
            .singleWhere((HabitEntity habit) => habit.id == 'walk')
            .status,
        HabitStatus.paused,
      );
      final int afterToggle = repository.saveCalls;
      await notifier.toggleHabit('missing');
      expect(repository.saveCalls, afterToggle);

      final String journalId = container
          .read(habitsProvider)
          .requireValue
          .first
          .id;
      await notifier.renameHabit(journalId, '  Evening journal  ');
      expect(
        container.read(habitsProvider).requireValue.first.title,
        'Evening journal',
      );
      final int afterRename = repository.saveCalls;
      await notifier.renameHabit(journalId, '  ');
      await notifier.renameHabit('missing', 'Missing');
      expect(repository.saveCalls, afterRename);

      await notifier.removeHabit('walk');
      expect(
        container
            .read(habitsProvider)
            .requireValue
            .map((HabitEntity habit) => habit.id),
        isNot(contains('walk')),
      );
      final int afterRemove = repository.saveCalls;
      await notifier.removeHabit('missing');
      expect(repository.saveCalls, afterRemove);

      await expectLater(notifier.completeHabit(journalId), throwsStateError);
      await expectLater(notifier.skipHabit(journalId), throwsStateError);
      expect(repository.saveCalls, 4);
    },
  );
}

final class _FakeHabitRepository implements IHabitRepository {
  _FakeHabitRepository(List<HabitEntity> habits)
    : _habits = List<HabitEntity>.from(habits);

  List<HabitEntity> _habits;
  int saveCalls = 0;

  @override
  Future<List<HabitEntity>> getHabits() async =>
      List<HabitEntity>.unmodifiable(_habits);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    saveCalls += 1;
    _habits = List<HabitEntity>.from(habits);
  }
}

final class _DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => 'false';

  @override
  Future<void> save(String key, String value) async {}
}

final class _NoopNotifications implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
