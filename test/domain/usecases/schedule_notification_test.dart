import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/schedule_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleNotification', () {
    late _FakeNotificationRepository repository;

    setUp(() {
      repository = _FakeNotificationRepository();
    });

    test('schedules valid notification', () async {
      final NotificationEntity notification = NotificationEntity(
        id: 'notif-1',
        title: 'Focus',
        message: 'Start now',
        scheduledAt: DateTime.now().add(const Duration(minutes: 3)),
      );

      await ScheduleNotification(repository).call(notification);

      expect(repository.scheduled.single.id, 'notif-1');
    });

    test('adapts message from SI decision action', () async {
      final NotificationEntity notification = NotificationEntity(
        id: 'notif-2',
        title: 'Nudge',
        message: 'Original',
        scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      await ScheduleNotification(
        repository,
        generateSiDecision: _StubGenerateSiDecision(
          const SiDecisionEntity(
            rationale: 'Adaptive',
            action: 'Execute one focused step now.',
          ),
        ),
      ).call(notification);

      expect(
        repository.scheduled.single.message,
        'Execute one focused step now.',
      );
    });

    test('throws for disabled or past notifications', () async {
      await expectLater(
        () => ScheduleNotification(repository).call(
          NotificationEntity(
            id: 'notif-disabled',
            title: 'Disabled',
            message: 'No',
            isEnabled: false,
            scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ),
        throwsException,
      );

      await expectLater(
        () => ScheduleNotification(repository).call(
          NotificationEntity(
            id: 'notif-past',
            title: 'Past',
            message: 'No',
            scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ),
        throwsException,
      );
    });
  });
}

class _StubGenerateSiDecision extends GenerateSiDecision {
  _StubGenerateSiDecision(this._decision)
    : super(_FakeTaskRepository(), _FakeSiRepository());

  final SiDecisionEntity _decision;

  @override
  Future<SiDecisionEntity> call([String input = '']) async => _decision;
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
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FakeSiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
