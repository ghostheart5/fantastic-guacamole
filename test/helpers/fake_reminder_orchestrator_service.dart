import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

class FakeReminderOrchestratorService extends ReminderOrchestratorService {
  FakeReminderOrchestratorService(AccountStorageScope scope)
    : super(
        preferences: _MemoryPrefs(),
        notifications: NotificationsService(_NoopNotifications()),
        scheduler: NotificationScheduler(),
        storageScope: scope,
      );

  final List<List<HabitRecord>> habitSyncCalls = <List<HabitRecord>>[];
  bool failHabitSync = false;

  @override
  Future<void> syncHabitReminders(List<HabitRecord> habits) async {
    if (failHabitSync) {
      throw StateError('Injected habit reminder sync failure.');
    }
    habitSyncCalls.add(List<HabitRecord>.from(habits));
  }

  void reset() {
    habitSyncCalls.clear();
    failHabitSync = false;
  }
}

class _MemoryPrefs implements SharedPrefsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => null;
  @override
  Future<void> save(String key, String value) async {}
}

class _NoopNotifications implements INotificationRepository {
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
