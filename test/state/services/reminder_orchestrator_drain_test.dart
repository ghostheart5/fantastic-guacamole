import 'dart:async';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains a pending reminder operation, repeats safely, and preserves durable state', () async {
    final _MemoryPrefs preferences = _MemoryPrefs(<String, String>{
      'goal_reminders_enabled': 'true',
      'daily_planning_reminder_enabled': 'true',
      'daily_planning_reminder_time': '07:30',
      'user_reminder_state': 'kept',
    });
    final _BlockingNotificationRepository repository = _BlockingNotificationRepository();
    final ReminderOrchestratorService service = ReminderOrchestratorService(
      preferences: preferences,
      notifications: NotificationsService(repository),
      scheduler: NotificationScheduler(),
    );
    final GoalEntity goal = GoalEntity(
      id: 'goal-1',
      title: 'Protect reminder state',
      createdAt: DateTime.utc(2026, 1, 1),
      targetDate: DateTime.now().add(const Duration(days: 2)),
    );

    final Future<void> scheduling = service.syncGoalReminders(<GoalEntity>[goal]);
    await repository.scheduleStarted.future;
    final Future<void> drain = service.cancelAndDrain();
    var drainCompleted = false;
    unawaited(drain.then((_) => drainCompleted = true));
    await Future<void>.delayed(Duration.zero);
    expect(drainCompleted, isFalse);

    repository.releaseSchedule();
    await scheduling;
    await drain;
    await service.cancelAndDrain();
    await service.cancelAndDrain();

    expect(repository.scheduled.map((NotificationEntity value) => value.id),
        <String>['goal_reminder_goal-1']);
    expect(preferences.values['daily_planning_reminder_enabled'], 'true');
    expect(preferences.values['daily_planning_reminder_time'], '07:30');
    expect(preferences.values['user_reminder_state'], 'kept');
    expect(preferences.deletedKeys, isEmpty);
    expect(preferences.clearCalls, 0);
  });
}

class _MemoryPrefs implements SharedPrefsStore {
  _MemoryPrefs(this.values);

  final Map<String, String> values;
  final List<String> deletedKeys = <String>[];
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    values.clear();
  }

  @override
  Future<void> delete(String key) async {
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}

class _BlockingNotificationRepository implements INotificationRepository {
  final Completer<void> scheduleStarted = Completer<void>();
  final Completer<void> _scheduleGate = Completer<void>();
  final List<NotificationEntity> scheduled = <NotificationEntity>[];

  void releaseSchedule() => _scheduleGate.complete();

  @override
  Future<void> cancelNotification(String id) async {
    scheduled.removeWhere((NotificationEntity value) => value.id == id);
  }

  @override
  Future<void> delete(String id) async {
    scheduled.removeWhere((NotificationEntity value) => value.id == id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async => scheduled;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    if (!scheduleStarted.isCompleted) scheduleStarted.complete();
    await _scheduleGate.future;
    scheduled.add(notification);
  }
}
