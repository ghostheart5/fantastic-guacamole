import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';
import 'package:fantastic_guacamole/state/services/state_si_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIEngineService', () {
    test('does not accept repeated output when dedup check fails', () {
      final SiEngineService service = SiEngineService(
        _NoopSiEngineRepository(),
        dependencies: _fakeDependencies(),
      );

      final bool accepted = service.validateOutput(
        message: 'Start with one focused block on your top priority task.',
        confidence: 0.82,
        deduped: false,
      );

      expect(accepted, isFalse);
    });

    test('accepts non-repeated output when validation flags are healthy', () {
      final SiEngineService service = SiEngineService(
        _NoopSiEngineRepository(),
        dependencies: _fakeDependencies(),
      );

      final bool accepted = service.validateOutput(
        message: 'Triage your top three tasks, then execute the first for 25 minutes.',
        confidence: 0.82,
        deduped: true,
      );

      expect(accepted, isTrue);
    });
  });
}

class _NoopSiEngineRepository implements SiEngineRepository {
  @override
  Future<Map<String, dynamic>?> loadState() async => null;

  @override
  Future<void> saveState(Map<String, dynamic> state) async {}
}

SiEngineDependencies _fakeDependencies() {
  return SiEngineDependencies(
    tasks: _FakeTaskRepository(),
    goals: _FakeGoalRepository(),
    insights: _FakeInsightRepository(),
    flowmap: _FakeFlowmapRepository(),
    logs: _FakeLogRepository(),
    timeline: _FakeTimelineRepository(),
    progression: _FakeProgressionRepository(),
    memories: _FakeMemoryRepository(),
    plan: _FakePlanRepository(),
    notifications: _FakeNotificationRepository(),
    profile: _FakeProfileRepository(),
  );
}

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FakeGoalRepository implements IGoalRepository {
  @override
  Future<void> deleteGoal(String id) async {}

  @override
  List<GoalEntity> getGoals() => const <GoalEntity>[];

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
}

class _FakeInsightRepository implements IInsightRepository {
  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<List<InsightEntity>> getInsights() async => const <InsightEntity>[];

  @override
  Future<void> removeInsight(String id) async {}

  @override
  Future<void> saveInsight(InsightEntity insight) async {}

  @override
  Future<List<InsightEntity>> searchInsights(String query) async => const <InsightEntity>[];
}

class _FakeFlowmapRepository implements IFlowmapRepository {
  @override
  Future<void> deleteNode(String id) async {}

  @override
  Future<List<FlowmapNode>> getNodes() async => const <FlowmapNode>[];

  @override
  Future<void> saveNode(FlowmapNode node) async {}

  @override
  Future<void> saveNodes(List<FlowmapNode> nodes) async {}
}

class _FakeLogRepository implements ILogRepository {
  @override
  Future<void> addLog(LogEntryEntity entry) async {}

  @override
  Future<List<LogEntryEntity>> getLogs() async => const <LogEntryEntity>[];
}

class _FakeTimelineRepository implements ITimelineRepository {
  @override
  Future<void> addEvent(TimelineEventEntity event) async {}

  @override
  List<TimelineEventEntity> getEvents() => const <TimelineEventEntity>[];

  @override
  Future<void> removeEvent(String id) async {}

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}
}

class _FakeProgressionRepository implements IProgressionRepository {
  @override
  Future<ProgressionEntity?> getProgression() async => const ProgressionEntity();

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {}
}

class _FakeMemoryRepository implements IMemoryRepository {
  @override
  Future<void> deleteMemory(String id) async {}

  @override
  List<MemoryEntity> getMemories() => const <MemoryEntity>[];

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {}

  @override
  Future<void> saveMemory(MemoryEntity memory) async {}
}

class _FakePlanRepository implements IPlanRepository {
  @override
  Future<PlanEntity?> getPlan(DateTime date) async => null;

  @override
  Future<void> savePlan(PlanEntity plan) async {}
}

class _FakeNotificationRepository implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async => const <NotificationEntity>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}

class _FakeProfileRepository implements IProfileRepository {
  @override
  Future<ProfileEntity?> getProfile() async => const ProfileEntity();

  @override
  Future<void> saveProfile(ProfileEntity profile) async {}
}
