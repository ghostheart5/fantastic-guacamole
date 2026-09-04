import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'goal actions persist and fan out auditable lifecycle evidence',
    () async {
      final DateTime now = DateTime.utc(2026, 9, 3, 12);
      final _FakeGoalRepository goals = _FakeGoalRepository(<GoalEntity>[
        GoalEntity(id: 'active', title: 'Active goal', createdAt: now),
        GoalEntity(
          id: 'completed',
          title: 'Completed goal',
          createdAt: now,
          completedAt: now,
        ),
      ]);
      final _RecordingLogs logs = _RecordingLogs();
      final _RecordingTimeline timeline = _RecordingTimeline();
      final _RecordingProfile profile = _RecordingProfile();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainGoalRepositoryProvider.overrideWithValue(goals),
          domainTaskRepositoryProvider.overrideWithValue(
            _FakeTaskRepository(<TaskEntity>[
              TaskEntity(
                id: 'done',
                title: 'Done',
                goalId: 'active',
                isCompleted: true,
                createdAt: now,
              ),
              TaskEntity(
                id: 'open',
                title: 'Open',
                goalId: 'active',
                createdAt: now,
              ),
              TaskEntity(
                id: 'other',
                title: 'Other',
                goalId: 'elsewhere',
                createdAt: now,
              ),
            ]),
          ),
          domainSiRepositoryProvider.overrideWithValue(_EmptySiRepository()),
          reminderOrchestratorServiceProvider.overrideWithValue(
            ReminderOrchestratorService(
              preferences: _DisabledPreferences(),
              notifications: NotificationsService(_NoopNotifications()),
              scheduler: NotificationScheduler(),
              accountScope: null,
            ),
          ),
          logsProvider.overrideWith(() => logs),
          timelineProvider.overrideWith(() => timeline),
          profileProvider.overrideWith(() => profile),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(goalProvider).single.id, 'active');
      final GoalProgressView progress = await container.read(
        goalProgressProvider('active').future,
      );
      expect(progress.tasks, hasLength(2));
      expect(progress.completedCount, 1);

      final GoalsNotifier notifier = container.read(goalsProvider.notifier);
      await notifier.add(
        title: '  Finish Priority 7  ',
        description: '   ',
        targetDate: now.add(const Duration(days: 2)),
      );
      final GoalEntity created = container.read(goalsProvider).first;
      expect(created.title, 'Finish Priority 7');
      expect(created.description, isNull);

      final GoalEntity updated = created.copyWith(description: 'Coverage gate');
      await notifier.update(updated);
      expect(container.read(goalsProvider).first.description, 'Coverage gate');

      await notifier.complete(created.id);
      expect(
        container.read(goalsProvider).map((GoalEntity goal) => goal.id),
        isNot(contains(created.id)),
      );
      expect(
        goals.goals
            .singleWhere((GoalEntity goal) => goal.id == created.id)
            .isCompleted,
        isTrue,
      );

      await notifier.remove('active');
      expect(container.read(goalsProvider), isEmpty);
      expect(
        logs.records.map(
          (({String source, String message}) item) => item.source,
        ),
        <String>[
          'goal_created',
          'goal_updated',
          'goal_completed',
          'goal_completed',
        ],
      );
      expect(
        timeline.events.map((TimelineEventEntity event) => event.type),
        <TimelineEventType>[
          TimelineEventType.reflection,
          TimelineEventType.reflection,
          TimelineEventType.goalComplete,
          TimelineEventType.goalComplete,
        ],
      );
      expect(profile.awards, <int>[12, 6, 40, 40]);
      expect(goals.saveCalls, 4);
    },
  );
}

final class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(List<GoalEntity> goals)
    : goals = List<GoalEntity>.from(goals);

  final List<GoalEntity> goals;
  int saveCalls = 0;

  @override
  Future<void> deleteGoal(String id) async {
    goals.removeWhere((GoalEntity goal) => goal.id == id);
  }

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.unmodifiable(goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    saveCalls += 1;
    final int index = goals.indexWhere((GoalEntity item) => item.id == goal.id);
    if (index < 0) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    saveCalls += 1;
    this.goals
      ..clear()
      ..addAll(goals);
  }
}

final class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository(this.tasks);

  final List<TaskEntity> tasks;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

final class _EmptySiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}

final class _RecordingLogs extends LogsController {
  final List<({String source, String message})> records =
      <({String source, String message})>[];

  @override
  LogsState build() => LogsState.initial();

  @override
  Future<void> add({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool syncTimeline = true,
    bool refreshPlanner = true,
    bool updateSignals = false,
  }) async {
    records.add((source: source, message: message));
  }
}

final class _RecordingTimeline extends TimelineNotifier {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];

  @override
  Future<void> record(
    TimelineEventEntity event, {
    bool refreshPlanner = true,
    bool awardProgression = false,
  }) async {
    events.add(event);
  }
}

final class _RecordingProfile extends ProfileController {
  final List<int> awards = <int>[];

  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> awardXP(int amount, {required String source}) async {
    awards.add(amount);
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
