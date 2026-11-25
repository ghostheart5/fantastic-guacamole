import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../permissions/notification_permission_test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<(PermissionFixture, _Goals)> saveGoal(
    WidgetTester tester, {
    required bool withDate,
    bool goalReminders = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final goals = _Goals();
    final fixture = PermissionFixture(
      overrides: [
        sensitivePrefsStoreProvider.overrideWithValue(MemoryPrefs()),
        domainTaskRepositoryProvider.overrideWithValue(_Tasks()),
        domainGoalRepositoryProvider.overrideWithValue(goals),
        // Only the save itself; its follow-up work is covered elsewhere.
        goalsProvider.overrideWith(_GoalsNotifier.new),
        domainHabitRepositoryProvider.overrideWithValue(_Habits()),
        domainNoteRepositoryProvider.overrideWithValue(_Notes()),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    if (!goalReminders) {
      fixture.actions.reminderPrefs = const ReminderOrchestratorPrefs(
        goalRemindersEnabled: false,
        habitRemindersEnabled: true,
        dailyPlanningEnabled: true,
        dailyPlanningHour: 7,
        dailyPlanningMinute: 30,
      );
    }
    final container = fixture.container;
    await container.read(adaptiveGuidanceProvider.future);
    for (final milestone in [
      GuidanceMilestone.firstItem,
      GuidanceMilestone.firstSchedule,
      GuidanceMilestone.firstTimelineReview,
    ]) {
      await container.read(adaptiveGuidanceProvider.notifier).record(milestone);
    }
    container
        .read(creatorNavigationIntentProvider.notifier)
        .open(CreatorFormKind.goal);
    await tester.pumpWidget(
      fixture.app(
        Builder(
          // The animated backdrop only settles with animations off.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const CreatorScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Run a 10K');
    if (withDate) {
      await tester.ensureVisible(find.text('Add a target date (optional)'));
      await tester.tap(find.text('Add a target date (optional)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add target date...'));
      await tester.tap(find.text('Add target date...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    // The confirmed save and its follow-up work finish over several frames.
    for (var i = 0; i < 40 && find.text('Saved').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    return (fixture, goals);
  }

  testWidgets('a goal saved in the Creator with a date asks after saving', (
    tester,
  ) async {
    final (fixture, goals) = await saveGoal(tester, withDate: true);

    expect(goals.saved.single.targetDate, isNotNull);
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(fixture.actions.requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a goal saved in the Creator without a date does not ask', (
    tester,
  ) async {
    final (fixture, goals) = await saveGoal(tester, withDate: false);

    expect(goals.saved.single.targetDate, isNull);
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(fixture.scheduler.queries, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with goal reminders off a Creator goal does not ask', (
    tester,
  ) async {
    final (fixture, goals) = await saveGoal(
      tester,
      withDate: true,
      goalReminders: false,
    );

    expect(goals.saved.single.targetDate, isNotNull);
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(fixture.actions.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _GoalsNotifier extends GoalsNotifier {
  @override
  List<GoalEntity> build() => ref.read(domainGoalRepositoryProvider).getGoals();

  @override
  Future<GoalMutationResult> addEntity(GoalEntity goal) async {
    await ref.read(domainGoalRepositoryProvider).saveGoal(goal);
    state = [goal, ...state];
    return const GoalMutationResult();
  }
}

class _Goals implements IGoalRepository {
  final List<GoalEntity> saved = <GoalEntity>[];
  @override
  Future<void> deleteGoal(String id) async =>
      saved.removeWhere((goal) => goal.id == id);
  @override
  List<GoalEntity> getGoals() => List.of(saved);
  @override
  Future<void> saveGoal(GoalEntity goal) async {
    saved
      ..removeWhere((value) => value.id == goal.id)
      ..add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    saved
      ..clear()
      ..addAll(goals);
  }
}

class _Tasks implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _Habits implements IHabitRepository {
  @override
  Future<List<HabitEntity>> getHabits() async => const <HabitEntity>[];
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}

class _Notes implements INoteRepository {
  @override
  Future<void> deleteNote(String id) async {}
  @override
  Future<List<NoteEntity>> getNotes() async => const <NoteEntity>[];
  @override
  Future<void> saveNote(NoteEntity note) async {}
}
