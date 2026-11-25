import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final result in NotificationScheduleResult.values) {
    test('turning daily planning on reports ${result.name}', () async {
      final scheduler = _Scheduler(result);
      final service = _service(scheduler);

      expect(
        await service.setDailyPlanningReminder(
          enabled: true,
          hour: 8,
          minute: 15,
        ),
        result,
      );
      expect(scheduler.daily, ['daily_planning_reminder']);
    });
  }

  test('turning daily planning off has nothing left to register', () async {
    final scheduler = _Scheduler(NotificationScheduleResult.permissionDenied);
    final service = _service(scheduler);

    expect(
      await service.setDailyPlanningReminder(
        enabled: false,
        hour: 8,
        minute: 15,
      ),
      NotificationScheduleResult.scheduled,
    );
    expect(scheduler.daily, isEmpty);
  });

  test('an account change part way reports nothing', () async {
    final scheduler = _Scheduler(NotificationScheduleResult.scheduled);
    final service = _service(scheduler);

    expect(
      await service.ensureDailyPlanningReminder(shouldContinue: () => false),
      isNull,
    );
  });
}

ReminderOrchestratorService _service(_Scheduler scheduler) =>
    ReminderOrchestratorService(
      preferences: _Preferences(),
      notifications: NotificationsService(_Repository()),
      scheduler: scheduler,
      accountScope: 'qa',
      now: () => DateTime(2026, 11, 13, 14),
      timeZoneName: () => 'Etc/UTC',
    );

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

class _Scheduler implements NotificationSchedulerPort {
  _Scheduler(this.result);
  final NotificationScheduleResult result;
  final daily = <String>[];

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    daily.add(id);
    return result;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => result;

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => result;

  @override
  Future<bool> cancel(String id, {String? accountScope}) async => true;
  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      const <String>[];
  @override
  Future<bool> requestPermissions() async =>
      throw StateError('Saving a reminder never asks for permission.');
  @override
  Future<bool> cancelAll() async => true;
  @override
  void clearTappedPayload() {}
}

class _Repository implements INotificationRepository {
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
