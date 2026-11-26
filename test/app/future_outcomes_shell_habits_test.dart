@Timeout(Duration(seconds: 120))
library;

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/future_outcomes_harness.dart';

/// The real shell keeps the Insights tab mounted (TickerMode off) while
/// another tab shows. Habit changes made there, and a midnight passed there,
/// must be on Future outcomes' "Habit check-ins" on the first settled frame
/// back, never the old list shown as current.
void main() {
  // A local afternoon; the forecast clock is UTC.
  DateTime clock = DateTime(2026, 12, 1, 15);

  HabitEntity habit(String id, String title, {DateTime? created}) =>
      HabitEntity(
        id: id,
        title: title,
        createdAt: created ?? DateTime(2026, 10, 1),
      );

  Future<
    ({ProviderContainer container, ValueNotifier<AppView> route, _Habits repo})
  >
  pumpShell(WidgetTester tester, List<HabitEntity> habits) async {
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final _Habits repo = _Habits(habits);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('insights-shell-test-account'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        unreadNotificationsProvider.overrideWithValue(0),
        goalsProvider.overrideWith(_StaticGoals.new),
        progressionProvider.overrideWithValue(ProgressionState.initial()),
        domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        domainHabitRepositoryProvider.overrideWithValue(repo),
        // The habit list as the app keeps it, without reminder scheduling:
        // a change saves to the store and then updates the list.
        habitsProvider.overrideWith(() => _TestHabits(repo)),
        habitOccurrencesProvider.overrideWith(
          (Ref ref) async => const <HabitOccurrenceEntity>[],
        ),
        trajectoryClockProvider.overrideWithValue(() => clock.toUtc()),
        // The forecast itself is not under test; the habit lines are real.
        trajectoryEngineModelProvider.overrideWith(
          (Ref ref) => futureOutcomesModel(
            days: ref.watch(trajectoryHorizonDaysProvider),
          ),
        ),
        trajectoryCalibrationSummaryProvider.overrideWithValue(
          const AsyncValue<TrajectoryCalibrationSummary>.data(
            futureOutcomesCalibration,
          ),
        ),
      ],
    );
    final ValueNotifier<AppView> route = ValueNotifier<AppView>(
      AppView.trajectoryEngine,
    );
    addTearDown(route.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ValueListenableBuilder<AppView>(
            valueListenable: route,
            builder: (BuildContext context, AppView view, Widget? _) =>
                NavigationShell(initialView: view),
          ),
        ),
      ),
    );
    return (container: container, route: route, repo: repo);
  }

  /// The habit rows under "Habit check-ins".
  List<String> rowKeys(WidgetTester tester) {
    final Finder block = find.byKey(const Key('keep-going-habits'));
    return find
        .descendant(
          of: block,
          matching: find.byWidgetPredicate((Widget w) {
            final Key? key = w.key;
            return key is ValueKey<String> &&
                key.value.startsWith('habit-line-');
          }),
        )
        .evaluate()
        .map((Element e) => (e.widget.key! as ValueKey<String>).value)
        .toList();
  }

  bool checking() => find
      .descendant(
        of: find.byKey(const Key('keep-going-habits')),
        matching: find.text('Checking your habits…'),
      )
      .evaluate()
      .isNotEmpty;

  /// Pumps until the habit block is built and not checking ("Checking your
  /// habits…" is an honest wait); returns the rows of that first settled
  /// frame.
  Future<List<String>> firstSettled(
    WidgetTester tester, {
    required List<String> expected,
  }) async {
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      if (find.byKey(const Key('keep-going-habits')).evaluate().isEmpty) {
        continue;
      }
      if (checking()) continue;
      return rowKeys(tester);
    }
    fail('Habit check-ins never settled (expected $expected)');
  }

  Future<void> showTab(
    WidgetTester tester,
    ValueNotifier<AppView> route,
    AppView view,
  ) async {
    route.value = view;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> reveal(WidgetTester tester) async {
    final Finder block = find.byKey(const Key('keep-going-habits'));
    if (block.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        block,
        300,
        scrollable: find
            .descendant(
              of: find.byType(TrajectoryEngineScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
  }

  testWidgets('add, rename and archive a habit on My plan, return: '
      'Habit check-ins shows the current habits', (WidgetTester tester) async {
    clock = DateTime(2026, 12, 1, 15);
    final shell = await pumpShell(tester, <HabitEntity>[
      habit('walk', 'Morning walk'),
      habit('read', 'Read a chapter'),
    ]);
    await reveal(tester);
    expect(
      await firstSettled(
        tester,
        expected: <String>['habit-line-walk', 'habit-line-read'],
      ),
      unorderedEquals(<String>['habit-line-walk', 'habit-line-read']),
    );
    expect(find.text('Morning walk'), findsOneWidget);

    await showTab(tester, shell.route, AppView.timeline);
    expect(
      tester
          .widget<TickerMode>(
            find
                .ancestor(
                  of: find.byType(TrajectoryEngineScreen, skipOffstage: false),
                  matching: find.byType(TickerMode, skipOffstage: false),
                )
                .first,
          )
          .enabled,
      isFalse,
      reason: 'Insights stays mounted with tickers off while hidden',
    );
    final _TestHabits habits =
        shell.container.read(habitsProvider.notifier) as _TestHabits;
    await habits.change(
      (List<HabitEntity> current) => <HabitEntity>[
        for (final HabitEntity h in current)
          if (h.id == 'walk')
            h.copyWith(title: 'Evening walk')
          else if (h.id == 'read')
            h.copyWith(status: HabitStatus.archived)
          else
            h,
        habit('stretch', 'Stretch'),
      ],
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    await showTab(tester, shell.route, AppView.trajectoryEngine);
    await reveal(tester);
    final List<String> rows = await firstSettled(
      tester,
      expected: <String>['habit-line-walk', 'habit-line-stretch'],
    );
    expect(
      rows,
      unorderedEquals(<String>['habit-line-walk', 'habit-line-stretch']),
    );
    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Morning walk'), findsNothing);
    expect(find.text('Read a chapter'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    shell.container.dispose();
  });

  testWidgets('midnight passes on another tab: the first settled frame back '
      'counts the new day', (WidgetTester tester) async {
    clock = DateTime(2026, 12, 1, 15);
    // Created two days ago: 2 closed days judged today, 3 after midnight.
    final shell = await pumpShell(tester, <HabitEntity>[
      habit('new', 'New habit', created: DateTime(2026, 11, 29, 8)),
    ]);
    await reveal(tester);
    await firstSettled(tester, expected: <String>['habit-line-new']);
    String rowText() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('habit-line-new')),
            matching: find.byType(Text),
          ),
        )
        .map((Text t) => t.data ?? '')
        .join(' | ');
    final String beforeText = rowText();
    expect(beforeText, contains('2 of'));

    await showTab(tester, shell.route, AppView.timeline);
    // Past local midnight: the clock moves and the rollover timer fires.
    clock = DateTime(2026, 12, 2, 0, 5);
    await tester.pump(const Duration(hours: 9, minutes: 10));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    await showTab(tester, shell.route, AppView.trajectoryEngine);
    await reveal(tester);
    await firstSettled(tester, expected: <String>['habit-line-new']);
    // The day that just closed is judged: the row is not the old one.
    expect(rowText(), isNot(beforeText));

    await tester.pumpWidget(const SizedBox());
    shell.container.dispose();
  });
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _NoTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}

  @override
  Future<void> deleteTask(String id) async {}
}

class _Habits implements IHabitRepository {
  _Habits(List<HabitEntity> habits) : _habits = List<HabitEntity>.of(habits);
  List<HabitEntity> _habits;

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(_habits);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    _habits = List<HabitEntity>.of(habits);
  }
}

class _TestHabits extends HabitsNotifier {
  _TestHabits(this._repo);
  final _Habits _repo;

  @override
  Future<List<HabitEntity>> build() => _repo.getHabits();

  /// Saves the changed list, then updates the list (as the app's habit
  /// actions do).
  Future<void> change(
    List<HabitEntity> Function(List<HabitEntity> current) edit,
  ) async {
    final List<HabitEntity> next = edit(await _repo.getHabits());
    await _repo.saveHabits(next);
    state = AsyncData<List<HabitEntity>>(next);
  }
}
