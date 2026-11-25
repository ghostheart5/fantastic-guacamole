import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const String testReminderScope = 'task-reminder-scope';

/// An in-memory task store that, like the real one, keeps removed tasks as
/// cancelled records.
class MemoryTaskStore implements ITaskRepository, IExactTaskSnapshotRepository {
  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    final TaskEntity? task = tasks[id];
    return task == null || task.isCanceled ? null : task;
  }

  @override
  Future<void> saveTask(TaskEntity task) async => tasks[task.id] = task;

  @override
  Future<void> deleteTask(String id) async {
    final TaskEntity? task = tasks[id];
    if (task != null) tasks[id] = task.cancel();
  }

  @override
  Future<void> replaceTaskSnapshot(List<TaskEntity> snapshot) async {
    tasks
      ..clear()
      ..addAll(<String, TaskEntity>{
        for (final task in snapshot) task.id: task,
      });
  }
}

/// A device whose OS reminders the test reads back. Nothing here touches a
/// platform channel.
class RecordingTaskScheduler implements NotificationScheduler {
  bool granted = true;
  final Set<String> pending = <String>{};
  final List<String> registered = <String>[];
  final List<String> cancelled = <String>[];
  final Map<String, DateTime> times = <String, DateTime>{};

  void clearLog() {
    registered.clear();
    cancelled.clear();
  }

  @override
  Future<bool> init({bool requestPermissions = false}) async {
    if (requestPermissions) throw StateError('Must not prompt for permission');
    return granted;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    expect(accountScope, testReminderScope);
    if (!granted) return NotificationScheduleResult.permissionDenied;
    registered.add(notification.id);
    pending.add(notification.id);
    times[notification.id] = notification.scheduledAt;
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    expect(accountScope, testReminderScope);
    cancelled.add(id);
    pending.remove(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async {
    expect(accountScope, testReminderScope);
    return pending.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryReminderPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
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

class NoNotificationList implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => const [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
