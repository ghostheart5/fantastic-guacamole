import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_habit_container.dart';
import '../../helpers/trajectory_live_container.dart';

/// Habit lines beside the forecast (trajectoryHabitLinesProvider): their own
/// per-account provider with an explicit status, live while watched, read the
/// account-safe way. Fixed local clock 2026-12-01 09:00; calendar fields.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 12, 1, 9);
  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 9);

  late TrajectoryMemoryStore store;
  late Map<String, List<HabitEntity>> habitsByUser;
  late Set<String> failingUsers;
  late DateTime Function() clock;

  setUp(() {
    store = TrajectoryMemoryStore();
    failingUsers = <String>{};
    clock = () => now;
    habitsByUser = <String, List<HabitEntity>>{
      'account-a': <HabitEntity>[trajectoryTestHabit('ha', 'Walk A')],
      'account-b': <HabitEntity>[trajectoryTestHabit('hb', 'Stretch B')],
    };
  });

  ProviderContainer build({int completed7d = 7, bool listen = true}) {
    final ProviderContainer container = trajectoryHabitContainer(
      now: now,
      clock: () => clock(),
      store: store,
      habitsByUser: habitsByUser,
      failingUsers: failingUsers,
      completed7d: completed7d,
    );
    addTearDown(container.dispose);
    if (listen) container.listen(trajectoryHabitLinesProvider, (_, _) {});
    return container;
  }

  /// The lines once they are no longer loading.
  Future<TrajectoryHabitLines> settled(ProviderContainer container) async {
    for (int i = 0; i < 500; i++) {
      final TrajectoryHabitLines lines = container.read(
        trajectoryHabitLinesProvider,
      );
      final AsyncValue<TrajectoryHabitSource> source = container.read(
        trajectoryHabitSourceProvider,
      );
      // A failed read may be retried by Riverpod (loading with the error);
      // the lines are unavailable throughout.
      if (lines.status != TrajectoryHabitLinesStatus.loading &&
          (!source.isLoading || source.hasError)) {
        return lines;
      }
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError('the habit lines never settled');
  }

  HabitEntity walkA() => habitsByUser['account-a']!.first;

  test('a daily habit done for 28 days is its own projected line', () async {
    await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
      for (int i = 1; i <= 28; i++) trajectoryTestCheckIn(walkA(), daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    final TrajectoryHabitLines lines = await settled(container);
    expect(lines.status, TrajectoryHabitLinesStatus.ready);
    expect(lines.horizonDays, 7);
    final TrajectoryHabitNode line = lines.nodes.single;
    expect(line.habitId, 'ha');
    expect(line.title, 'Walk A');
    expect(line.expectedPeriods, 7);
    expect(line.projectedCheckIns!.mid, 7);

    container.read(trajectoryHorizonDaysProvider.notifier).select(30);
    final TrajectoryHabitLines thirty = await settled(container);
    expect(thirty.horizonDays, 30);
    expect(thirty.nodes.single.expectedPeriods, 30);
    expect(thirty.nodes.single.projectedCheckIns!.mid, 30);
  });

  group('four distinguishable results', () {
    test('loading before the first read finishes', () {
      final ProviderContainer container = build();
      final TrajectoryHabitLines lines = container.read(
        trajectoryHabitLinesProvider,
      );
      expect(lines.status, TrajectoryHabitLinesStatus.loading);
      expect(lines.nodes, isEmpty);
    });

    test('ready with no habits', () async {
      habitsByUser['account-a'] = <HabitEntity>[];
      final TrajectoryHabitLines lines = await settled(build());
      expect(lines.status, TrajectoryHabitLinesStatus.ready);
      expect(lines.nodes, isEmpty);
      expect(lines.revision, 'none');
    });

    test('ready with habits', () async {
      final TrajectoryHabitLines lines = await settled(build());
      expect(lines.status, TrajectoryHabitLinesStatus.ready);
      expect(lines.nodes.map((TrajectoryHabitNode n) => n.habitId), <String>[
        'ha',
      ]);
      expect(lines.revision, isNot('none'));
    });

    test('unavailable when the read fails', () async {
      failingUsers.add('account-a');
      final ProviderContainer container = build();
      final TrajectoryHabitLines lines = await settled(container);
      expect(lines.status, TrajectoryHabitLinesStatus.unavailable);
      expect(lines.nodes, isEmpty);
      // The failure is kept as an error (and logged), not shown as no habits.
      expect(container.read(trajectoryHabitSourceProvider).hasError, isTrue);
    });

    test('unavailable while no account storage is ready', () async {
      final ProviderContainer container = build();
      (container.read(authSessionBoundaryProvider.notifier)
              as TrajectoryTestBoundary)
          .moveTo(
            const AuthSessionBoundary(
              generation: 2,
              userId: 'account-a',
              isTransitioning: true,
              isStorageReady: false,
            ),
          );
      expect(
        container.read(trajectoryHabitLinesProvider).status,
        TrajectoryHabitLinesStatus.unavailable,
      );
    });
  });

  test('a check-in refreshes the lines while watched', () async {
    await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
      for (int i = 2; i <= 10; i++) trajectoryTestCheckIn(walkA(), daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    final List<String> revisions = <String>[];
    container.listen(
      trajectoryHabitLinesProvider,
      (_, TrajectoryHabitLines next) => revisions.add(next.revision),
    );
    final TrajectoryHabitLines before = await settled(container);
    expect(before.nodes.single.completedPeriods, 9);
    expect(before.nodes.single.checkedInThisPeriod, isFalse);
    await container.read(habitsProvider.future);

    // A check-in for yesterday, recorded through the habit list.
    await container
        .read(habitsProvider.notifier)
        .recordHabitAt('ha', daysAgo(1), completed: true);
    await pumpEventQueue();
    final TrajectoryHabitLines afterYesterday = await settled(container);
    expect(afterYesterday.nodes.single.completedPeriods, 10);
    expect(
      afterYesterday.nodes.single.projectedCheckIns!.mid,
      greaterThan(before.nodes.single.projectedCheckIns!.mid),
    );
    expect(afterYesterday.revision, isNot(before.revision));

    // Today's check-in: the rate is unchanged, the line is not.
    await container.read(habitsProvider.notifier).completeHabit('ha');
    await pumpEventQueue();
    final TrajectoryHabitLines afterToday = await settled(container);
    expect(afterToday.nodes.single.checkedInThisPeriod, isTrue);
    expect(afterToday.revision, isNot(afterYesterday.revision));
    expect(revisions.toSet(), hasLength(greaterThanOrEqualTo(3)));
  });

  test('pausing a habit takes its line out', () async {
    final ProviderContainer container = build();
    expect((await settled(container)).nodes, hasLength(1));
    await container.read(habitsProvider.future);
    await container.read(habitsProvider.notifier).toggleHabit('ha');
    await pumpEventQueue();
    final TrajectoryHabitLines after = await settled(container);
    expect(after.status, TrajectoryHabitLinesStatus.ready);
    expect(after.nodes, isEmpty);
  });

  test('the comparison never reads habits', () async {
    final ProviderContainer container = build(listen: false);
    container.listen(trajectoryConsequenceProvider, (_, _) {});
    await container.read(siStateAggregationProvider.future);
    await pumpEventQueue();
    expect(container.read(trajectoryConsequenceProvider).hasValue, isTrue);
    expect(
      container.read(
        trajectoryHabitSourceForAccountProvider(
          trajectoryHabitAccountKey(
            container.read(trajectoryLiveAccountProvider).v2Namespace,
            1,
          ),
        ).exists,
      ),
      isFalse,
    );
  });

  test('A -> B -> A: no listener state ever holds the other account\'s '
      'habit', () async {
    await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
      for (int i = 1; i <= 5; i++) trajectoryTestCheckIn(walkA(), daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    final TrajectoryTestBoundary boundary =
        container.read(authSessionBoundaryProvider.notifier)
            as TrajectoryTestBoundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    expect(
      (await settled(container)).nodes.map((TrajectoryHabitNode h) => h.title),
      <String>['Walk A'],
    );

    bool shows(String habitId, TrajectoryHabitLines lines) =>
        lines.nodes.any((TrajectoryHabitNode h) => h.habitId == habitId);
    bool sourceShows(String habitId, AsyncValue<TrajectoryHabitSource> v) {
      final TrajectoryHabitSource? s = v.value;
      return s != null &&
          (s.habits.any((HabitEntity h) => h.id == habitId) ||
              s.occurrences.any(
                (HabitOccurrenceEntity o) => o.habitId == habitId,
              ));
    }

    final List<TrajectoryHabitLines> seen = <TrajectoryHabitLines>[];
    final List<AsyncValue<TrajectoryHabitSource>> seenSource =
        <AsyncValue<TrajectoryHabitSource>>[];
    final List<TrajectoryHabitLines> reads = <TrajectoryHabitLines>[];
    final List<AsyncValue<TrajectoryHabitSource>> sourceReads =
        <AsyncValue<TrajectoryHabitSource>>[];
    container.listen(trajectoryHabitLinesProvider, (_, next) => seen.add(next));
    container.listen(
      trajectoryHabitSourceProvider,
      (_, next) => seenSource.add(next),
    );
    // The steps of a real sign-out and sign-in (the fence invalidates the
    // habit list), reading what a screen would read after each one. The
    // habit providers themselves are not invalidated: the test does not rely
    // on the fence for them.
    void move(AuthSessionBoundary next) {
      boundary.moveTo(next);
      container.invalidate(habitsProvider);
      reads.add(container.read(trajectoryHabitLinesProvider));
      sourceReads.add(container.read(trajectoryHabitSourceProvider));
    }

    void expectNone(String habitId) {
      expect(seen.where((l) => shows(habitId, l)), isEmpty);
      expect(reads.where((l) => shows(habitId, l)), isEmpty);
      expect(seenSource.where((v) => sourceShows(habitId, v)), isEmpty);
      expect(sourceReads.where((v) => sourceShows(habitId, v)), isEmpty);
    }

    // A to B.
    move(
      const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
    );
    move(
      const AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final TrajectoryHabitLines b = await settled(container);
    await pumpEventQueue();
    reads.add(container.read(trajectoryHabitLinesProvider));
    sourceReads.add(container.read(trajectoryHabitSourceProvider));
    expect(b.nodes.map((TrajectoryHabitNode h) => h.title), <String>[
      'Stretch B',
    ]);
    expect(seen, isNotEmpty);
    expect(seenSource, isNotEmpty);
    expect(
      seen.map((TrajectoryHabitLines l) => l.status),
      contains(TrajectoryHabitLinesStatus.loading),
    );
    expectNone('ha');

    // B back to A.
    seen.clear();
    seenSource.clear();
    reads.clear();
    sourceReads.clear();
    move(
      const AuthSessionBoundary(
        generation: 5,
        userId: 'account-a',
        isTransitioning: true,
        isStorageReady: false,
      ),
    );
    move(
      const AuthSessionBoundary(
        generation: 6,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final TrajectoryHabitLines backToA = await settled(container);
    await pumpEventQueue();
    reads.add(container.read(trajectoryHabitLinesProvider));
    sourceReads.add(container.read(trajectoryHabitSourceProvider));
    expect(backToA.nodes.map((TrajectoryHabitNode h) => h.title), <String>[
      'Walk A',
    ]);
    expect(backToA.nodes.single.completedPeriods, 5);
    expectNone('hb');
  });

  test('a source of another account is never used', () {
    final TrajectoryHabitLines lines = trajectoryHabitLinesFrom(
      source: AsyncData<TrajectoryHabitSource>(
        TrajectoryHabitSource(
          namespace: 'v2.other',
          habits: <HabitEntity>[trajectoryTestHabit('ha', 'Walk A')],
          occurrences: const <HabitOccurrenceEntity>[],
        ),
      ),
      namespace: 'v2.mine',
      now: now,
      horizonDays: 7,
    );
    expect(lines.status, TrajectoryHabitLinesStatus.loading);
    expect(lines.nodes, isEmpty);
  });

  testWidgets('the lines are worked out again when the local day changes', (
    WidgetTester tester,
  ) async {
    DateTime moment = DateTime(2026, 12, 1, 23);
    clock = () => moment;
    await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
      for (int i = 0; i <= 27; i++) trajectoryTestCheckIn(walkA(), daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    // Fake time: reads finish as the test pumps.
    Future<TrajectoryHabitLines> settle() async {
      for (int i = 0; i < 50; i++) {
        final TrajectoryHabitLines lines = container.read(
          trajectoryHabitLinesProvider,
        );
        if (lines.status == TrajectoryHabitLinesStatus.ready) return lines;
        await tester.pump(const Duration(milliseconds: 1));
      }
      throw StateError('the habit lines never settled');
    }

    final TrajectoryHabitNode before = (await settle()).nodes.single;
    // Closed days Nov 3-30; Nov 3 has no check-in, today (Dec 1) does.
    expect(before.completedPeriods, 27);
    expect(before.checkedInThisPeriod, isTrue);

    moment = DateTime(2026, 12, 2, 0, 0, 5);
    await tester.pump(const Duration(hours: 1, seconds: 2));
    final TrajectoryHabitNode after = (await settle()).nodes.single;
    // Closed days Nov 4 - Dec 1, all checked in; Dec 2 is open.
    expect(after.completedPeriods, 28);
    expect(after.checkedInThisPeriod, isFalse);
    // The pending day-change timer goes with the provider.
    container.dispose();
  });

  test(
    '2 observed outcomes plus ten habit check-ins is still learning',
    () async {
      await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
        for (int i = 1; i <= 10; i++)
          trajectoryTestCheckIn(walkA(), daysAgo(i)),
      ]);
      final ProviderContainer container = build(completed7d: 2);
      container.listen(trajectoryConsequenceProvider, (_, _) {});
      final TrajectoryHabitLines lines = await settled(container);
      expect(lines.nodes.single.completedPeriods, 10);
      await pumpEventQueue();
      final TrajectoryComparison c = container
          .read(trajectoryConsequenceProvider)
          .requireValue;
      expect(c.baseline.observationCount, 2);
      expect(trajectoryHasMinimumEvidence(c), isFalse);
      expect(trajectoryCanRecommend(c), isFalse);
      final TrajectoryEngineModel model = container.read(
        trajectoryEngineModelProvider,
      );
      expect(trajectoryMinimumObservedOutcomes, 3);
      expect(model.status, TrajectoryEngineStatus.learning);
      // Nothing is recorded below the minimum.
      expect(
        store.values.keys.where(
          (String k) => k.startsWith('chronospark.trajectory.forecast_ledger'),
        ),
        isEmpty,
      );
    },
  );
}
