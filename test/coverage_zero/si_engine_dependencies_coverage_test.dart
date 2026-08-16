import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}

  @override
  Future<void> deleteTask(String id) async {}
}

class _FakeGoalRepository implements IGoalRepository {
  @override
  List<GoalEntity> getGoals() => <GoalEntity>[];

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

class _FakeInsightRepository implements IInsightRepository {
  @override
  Future<List<InsightEntity>> getInsights() async => <InsightEntity>[];

  @override
  Future<void> saveInsight(InsightEntity insight) async {}

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<void> removeInsight(String id) async {}

  @override
  Future<List<InsightEntity>> searchInsights(String query) async =>
      <InsightEntity>[];
}

class _FakeLogRepository implements ILogRepository {
  @override
  Future<List<LogEntryEntity>> getLogs() async => <LogEntryEntity>[];

  @override
  Future<void> addLog(LogEntryEntity entry) async {}
}

class _FakeTimelineRepository implements ITimelineRepository {
  @override
  List<TimelineEventEntity> getEvents() => <TimelineEventEntity>[];

  @override
  Future<void> addEvent(TimelineEventEntity event) async {}

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}

  @override
  Future<void> removeEvent(String id) async {}
}

class _FakeProgressionRepository implements IProgressionRepository {
  @override
  Future<ProgressionEntity?> getProgression() async => null;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {}
}

class _FakeMemoryRepository implements IMemoryRepository {
  @override
  List<MemoryEntity> getMemories() => <MemoryEntity>[];

  @override
  Future<void> saveMemory(MemoryEntity memory) async {}

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {}

  @override
  Future<void> deleteMemory(String id) async {}
}

class _FakePlanRepository implements IPlanRepository {
  @override
  Future<PlanEntity?> getPlan(DateTime date) async => null;

  @override
  Future<void> savePlan(PlanEntity plan) async {}
}

class _FakeNotificationRepository implements INotificationRepository {
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      <NotificationEntity>[];

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}

  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  test('si engine dependencies preserve repository references', () {
    final _FakeTaskRepository tasks = _FakeTaskRepository();
    final _FakeGoalRepository goals = _FakeGoalRepository();
    final _FakeInsightRepository insights = _FakeInsightRepository();
    final _FakeLogRepository logs = _FakeLogRepository();
    final _FakeTimelineRepository timeline = _FakeTimelineRepository();
    final _FakeProgressionRepository progression = _FakeProgressionRepository();
    final _FakeMemoryRepository memories = _FakeMemoryRepository();
    final _FakePlanRepository plan = _FakePlanRepository();
    final _FakeNotificationRepository notifications =
        _FakeNotificationRepository();
    final SiEngineDependencies dependencies = SiEngineDependencies(
      tasks: tasks,
      goals: goals,
      insights: insights,
      logs: logs,
      timeline: timeline,
      progression: progression,
      memories: memories,
      plan: plan,
      notifications: notifications,
    );

    expect(identical(dependencies.tasks, tasks), isTrue);
    expect(identical(dependencies.goals, goals), isTrue);
    expect(identical(dependencies.insights, insights), isTrue);
    expect(identical(dependencies.logs, logs), isTrue);
    expect(identical(dependencies.timeline, timeline), isTrue);
    expect(identical(dependencies.progression, progression), isTrue);
    expect(identical(dependencies.memories, memories), isTrue);
    expect(identical(dependencies.plan, plan), isTrue);
    expect(identical(dependencies.notifications, notifications), isTrue);
  });
}
