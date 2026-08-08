import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scheduleNotificationUseCaseProvider wires generateSiDecision so a '
    'scheduled notification is adapted through the SI pipeline instead of '
    'always shipping its original, non-adaptive message',
    () async {
      final _FakeNotificationRepository notificationRepository =
          _FakeNotificationRepository();
      final _FakeTaskRepository taskRepository = _FakeTaskRepository();
      final _FakeSiRepository siRepository = _FakeSiRepository();

      await taskRepository.saveTask(
        TaskEntity(
          id: 'task-1',
          title: 'Ship report',
          priority: 9,
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      siRepository.state = SiStateEntity(energy: 0.8, focus: 0.8, fatigue: 0.1);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainNotificationRepositoryProvider.overrideWithValue(
            notificationRepository,
          ),
          domainTaskRepositoryProvider.overrideWithValue(taskRepository),
          domainSiRepositoryProvider.overrideWithValue(siRepository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(scheduleNotificationUseCaseProvider)
          .call(
            NotificationEntity(
              id: 'notif-1',
              title: 'Nudge',
              message: 'Original message',
              scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
            ),
          );

      expect(
        notificationRepository.scheduled.single.message,
        'Focus on: Ship report',
        reason:
            'scheduleNotificationUseCaseProvider must supply generateSiDecision '
            'so ScheduleNotification actually adapts the notification message '
            'through the SI pipeline when wired via the real provider graph.',
      );
    },
  );
}

class _FakeNotificationRepository implements INotificationRepository {
  final List<NotificationEntity> scheduled = <NotificationEntity>[];

  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async => scheduled;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    scheduled.add(notification);
  }
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => _tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}

class _FakeSiRepository implements ISiRepository {
  SiStateEntity? state;

  @override
  Future<SiStateEntity?> getCurrentState() async => state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    this.state = state;
  }
}
