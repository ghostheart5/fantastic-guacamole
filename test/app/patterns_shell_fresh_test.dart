@Timeout(Duration(seconds: 120))
library;

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/patterns_screen_harness.dart';

/// The real path in the app: Patterns is the shell's overlay inside the
/// Insights tab, removed (and its provider disposed) when you leave. Leave
/// Patterns, finish a task elsewhere, come back: the figures are fresh, and
/// the old ones are never shown as current.
void main() {
  testWidgets('leave Patterns, finish a task elsewhere, come back: fresh '
      'figures', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final List<TaskEntity> tasks = <TaskEntity>[
      openTask('open', title: 'Write report', minutes: 30),
    ];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('patterns-shell-test-account'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        unreadNotificationsProvider.overrideWithValue(0),
        goalsProvider.overrideWith(_StaticGoals.new),
        progressionProvider.overrideWithValue(ProgressionState.initial()),
        // Future outcomes' habit lines are not under test here; the Patterns
        // provider is the real one.
        trajectoryHabitLinesProvider.overrideWith(
          (Ref ref) => TrajectoryHabitLines(
            status: TrajectoryHabitLinesStatus.ready,
            horizonDays: ref.watch(trajectoryHorizonDaysProvider),
          ),
        ),
        patternsClockProvider.overrideWithValue(() => patternsNow),
        domainTaskRepositoryProvider.overrideWithValue(_Tasks(tasks)),
        domainHabitRepositoryProvider.overrideWithValue(_NoHabits()),
        // Stored check-ins live on disk; none here.
        habitOccurrencesProvider.overrideWith(
          (Ref ref) async => const <HabitOccurrenceEntity>[],
        ),
      ],
    );

    final ValueNotifier<AppView> route = ValueNotifier<AppView>(
      AppView.progression,
    );
    addTearDown(route.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The router rebuilds the same shell with the route's view.
        child: MaterialApp(
          home: ValueListenableBuilder<AppView>(
            valueListenable: route,
            builder: (BuildContext context, AppView view, Widget? _) =>
                NavigationShell(initialView: view),
          ),
        ),
      ),
    );

    Finder tasksFinished(String value) => find.descendant(
      of: inPatternsSection(
        'patterns-trend',
        find.ancestor(
          of: find.text('Tasks finished'),
          matching: find.byType(PlainMetricRow),
        ),
      ),
      matching: find.text(value),
    );
    final Finder staleEmpty = find.textContaining(
      'Nothing recorded in these days.',
    );
    final Finder updating = find.text('Updating from your records…');

    Future<void> settle() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 1));
        if (find.text('Reading your records…').evaluate().isEmpty &&
            updating.evaluate().isEmpty) {
          return;
        }
      }
      fail('Patterns never settled');
    }

    await settle();
    expect(find.byType(ProgressionScreen), findsOneWidget);
    expect(staleEmpty, findsOneWidget);

    // Leave Patterns for Today: the overlay is removed.
    route.value = AppView.nexus;
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byType(ProgressionScreen), findsNothing);

    // A task is finished elsewhere: the saved task changes and the task list
    // reloads (what TaskActions.completeTask ends with).
    tasks[0] = tasks[0].copyWith(isCompleted: true, completedAt: patternsNow);
    container.invalidate(allTasksProvider);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    // Come back: no frame shows the old figures as current.
    route.value = AppView.progression;
    bool fresh = false;
    for (int i = 0; i < 100 && !fresh; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      fresh = tasksFinished('1').evaluate().isNotEmpty;
      if (!fresh && staleEmpty.evaluate().isNotEmpty) {
        expect(updating, findsOneWidget, reason: 'stale figures unmarked');
      }
    }
    expect(fresh, isTrue);
    await settle();
    expect(tasksFinished('1'), findsOneWidget);

    // The day-change timer goes with the provider.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _Tasks implements ITaskRepository {
  _Tasks(this._records);
  final List<TaskEntity> _records;

  @override
  Future<List<TaskEntity>> getAllTasks() async => List<TaskEntity>.of(_records);

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      _records.where((TaskEntity t) => t.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {
    final int i = _records.indexWhere((TaskEntity t) => t.id == task.id);
    if (i >= 0) {
      _records[i] = task;
    } else {
      _records.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async =>
      _records.removeWhere((TaskEntity t) => t.id == id);
}

class _NoHabits implements IHabitRepository {
  @override
  Future<List<HabitEntity>> getHabits() async => const <HabitEntity>[];

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}
