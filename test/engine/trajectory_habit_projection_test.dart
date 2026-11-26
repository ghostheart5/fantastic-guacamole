import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/trajectory_habit_projection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Habits in the forecast: one projected line per active habit, from its
/// closed periods. Fixed local clock 2026-12-01 09:00 (a Tuesday); calendar
/// fields only.
void main() {
  final DateTime now = DateTime(2026, 12, 1, 9);
  DateTime daysAgo(int n, [int hour = 9]) =>
      DateTime(now.year, now.month, now.day - n, hour);

  HabitOccurrenceEntity record(
    HabitEntity habit,
    DateTime at, {
    HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.completed,
  }) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
    operationId: 'op-${habit.id}-${at.toIso8601String()}',
    outcome: outcome,
    recordedAt: at.toUtc(),
  );

  HabitEntity habit({
    String id = 'walk',
    String title = 'Walk',
    HabitCadence cadence = HabitCadence.daily,
    DateTime? createdAt,
    int revision = 0,
    DateTime? startedAt,
    HabitStatus status = HabitStatus.active,
  }) => HabitEntity(
    id: id,
    title: title,
    cadence: cadence,
    createdAt: createdAt ?? DateTime(2026, 9, 1, 8),
    frequencyRevision: revision,
    frequencyStartedAt: startedAt,
    status: status,
  );

  List<TrajectoryHabitNode> nodes(
    List<HabitEntity> habits,
    List<HabitOccurrenceEntity> occurrences, {
    int horizonDays = 7,
  }) => TrajectoryHabitProjection.nodes(
    habits: habits,
    occurrences: occurrences,
    now: now,
    horizonDays: horizonDays,
  );

  group('daily habit done every day for the last 28 days', () {
    final HabitEntity walk = habit();
    final List<HabitOccurrenceEntity> done = <HabitOccurrenceEntity>[
      for (int i = 1; i <= 28; i++) record(walk, daysAgo(i)),
    ];

    test('range 7: 7 expected periods, mid 7, low and high within 0..7', () {
      final TrajectoryHabitNode n = nodes(<HabitEntity>[walk], done).single;
      expect(n.habitId, 'walk');
      expect(n.title, 'Walk');
      expect(n.cadence, HabitCadence.daily);
      expect(n.evidence, TrajectoryHabitEvidence.enough);
      expect(n.closedPeriodsJudged, 28);
      expect(n.completedPeriods, 28);
      expect(n.rate, 1.0);
      expect(n.expectedPeriods, 7);
      expect(n.projectedCheckIns!.mid, 7);
      // ceil(sqrt(7)) = 3 below; the top is clamped to the 7 periods.
      expect(n.projectedCheckIns!.low, 4);
      expect(n.projectedCheckIns!.high, 7);
    });

    test('range 30: 30 expected periods, mid 30', () {
      final TrajectoryHabitNode n = nodes(
        <HabitEntity>[walk],
        done,
        horizonDays: 30,
      ).single;
      expect(n.expectedPeriods, 30);
      expect(n.projectedCheckIns!.mid, 30);
      expect(n.projectedCheckIns!.low, inInclusiveRange(0, 30));
      expect(n.projectedCheckIns!.high, 30);
    });

    test('range 90: 90 expected periods; older check-ins are not judged', () {
      final TrajectoryHabitNode n = nodes(
        <HabitEntity>[walk],
        <HabitOccurrenceEntity>[
          ...done,
          // Outside the 28-day look-back: ignored.
          record(walk, daysAgo(40)),
        ],
        horizonDays: 90,
      ).single;
      expect(n.expectedPeriods, 90);
      expect(n.closedPeriodsJudged, 28);
      expect(n.completedPeriods, 28);
    });
  });

  test('weekly habit done in 2 of the last 4 closed weeks, range 30', () {
    final HabitEntity gym = habit(id: 'gym', cadence: HabitCadence.weekly);
    // Closed weeks: Nov 2, 9, 16 and 23 (Mondays). Done in the weeks of
    // Nov 9 and Nov 23; this week (from Nov 30) is open and not judged.
    final TrajectoryHabitNode n = nodes(
      <HabitEntity>[gym],
      <HabitOccurrenceEntity>[
        record(gym, DateTime(2026, 11, 10, 9)),
        record(gym, DateTime(2026, 11, 25, 9)),
        // Week of Oct 26: before the 4-week look-back.
        record(gym, DateTime(2026, 10, 27, 9)),
      ],
      horizonDays: 30,
    ).single;
    expect(n.closedPeriodsJudged, 4);
    expect(n.completedPeriods, 2);
    expect(n.rate, 0.5);
    expect(n.expectedPeriods, 5); // ceil(30 / 7)
    // round(0.5 x 5) = round(2.5) = 3 (halves round up).
    expect(n.projectedCheckIns!.mid, 3);
    expect(n.projectedCheckIns!.low, 1); // 3 - ceil(sqrt(3))
    expect(n.projectedCheckIns!.high, 5);
  });

  test('monthly habit is judged on its last 3 closed months', () {
    final HabitEntity bills = habit(id: 'bills', cadence: HabitCadence.monthly);
    final TrajectoryHabitNode n = nodes(
      <HabitEntity>[bills],
      <HabitOccurrenceEntity>[
        record(bills, DateTime(2026, 9, 3, 9)),
        record(bills, DateTime(2026, 11, 3, 9)),
      ],
      horizonDays: 90,
    ).single;
    // September, October and November; December is the open period.
    expect(n.closedPeriodsJudged, 3);
    expect(n.completedPeriods, 2);
    expect(n.expectedPeriods, 3); // ceil(90 / 30)
    expect(n.projectedCheckIns!.mid, 2);
    expect(n.projectedCheckIns!.low, 0);
    expect(n.projectedCheckIns!.high, 3);
  });

  test('2 closed periods: not enough history, 2 of 3, no projection', () {
    final HabitEntity fresh = habit(createdAt: daysAgo(2, 8));
    final TrajectoryHabitNode n = nodes(
      <HabitEntity>[fresh],
      <HabitOccurrenceEntity>[
        record(fresh, daysAgo(1)),
        record(fresh, daysAgo(2)),
      ],
    ).single;
    expect(n.evidence, TrajectoryHabitEvidence.notEnoughHistory);
    expect(n.closedPeriodsJudged, 2);
    expect(n.historyNeeded, 3);
    expect(n.completedPeriods, 2);
    expect(n.rate, isNull);
    expect(n.projectedCheckIns, isNull);
    // The range's periods are a calendar fact, not a projection.
    expect(n.expectedPeriods, 7);
  });

  test('a frequency edited 5 days ago judges only the periods since', () {
    final HabitEntity edited = habit(revision: 1, startedAt: daysAgo(5, 8));
    final TrajectoryHabitNode n = nodes(
      <HabitEntity>[edited],
      <HabitOccurrenceEntity>[
        // Before the edit: other revision's keys, never judged.
        for (int i = 6; i <= 28; i++) record(habit(), daysAgo(i)),
        for (int i = 1; i <= 5; i++) record(edited, daysAgo(i)),
      ],
    ).single;
    expect(n.closedPeriodsJudged, 5);
    expect(n.completedPeriods, 5);
    expect(n.rate, 1.0);
  });

  test('skipped and missed closed periods count as not done', () {
    final HabitEntity walk = habit();
    final TrajectoryHabitNode n = nodes(
      <HabitEntity>[walk],
      <HabitOccurrenceEntity>[
        for (int i = 1; i <= 14; i++) record(walk, daysAgo(i)),
        record(walk, daysAgo(15), outcome: HabitOccurrenceOutcome.skipped),
      ],
    ).single;
    expect(n.closedPeriodsJudged, 28);
    expect(n.completedPeriods, 14);
    expect(n.rate, 0.5);
    expect(n.projectedCheckIns!.mid, 4); // round(3.5)
  });

  test('today\'s check-in is reported but does not change the rate', () {
    final HabitEntity walk = habit();
    final List<HabitOccurrenceEntity> history = <HabitOccurrenceEntity>[
      for (int i = 1; i <= 7; i++) record(walk, daysAgo(i)),
    ];
    final TrajectoryHabitNode before = nodes(<HabitEntity>[
      walk,
    ], history).single;
    final TrajectoryHabitNode after = nodes(
      <HabitEntity>[walk],
      <HabitOccurrenceEntity>[...history, record(walk, now)],
    ).single;
    expect(before.checkedInThisPeriod, isFalse);
    expect(after.checkedInThisPeriod, isTrue);
    expect(after.rate, before.rate);
    expect(
      TrajectoryHabitProjection.revision(<TrajectoryHabitNode>[after]),
      isNot(TrajectoryHabitProjection.revision(<TrajectoryHabitNode>[before])),
    );
  });

  test('paused and archived habits do not appear', () {
    final List<TrajectoryHabitNode> n = nodes(<HabitEntity>[
      habit(id: 'active', title: 'Active'),
      habit(id: 'paused', status: HabitStatus.paused),
      habit(id: 'archived', status: HabitStatus.archived),
    ], const <HabitOccurrenceEntity>[]);
    expect(n.map((TrajectoryHabitNode x) => x.habitId), <String>['active']);
    expect(n.single.completedPeriods, 0);
    expect(n.single.rate, 0);
    expect(n.single.projectedCheckIns!.mid, 0);
    expect(n.single.projectedCheckIns!.high, 0);
  });

  test('nodes are ordered by title then id, and the revision is stable', () {
    final List<HabitEntity> habits = <HabitEntity>[
      habit(id: 'b', title: 'Read'),
      habit(id: 'a', title: 'Read'),
      habit(id: 'c', title: 'Floss'),
    ];
    final List<TrajectoryHabitNode> first = nodes(
      habits,
      const <HabitOccurrenceEntity>[],
    );
    expect(first.map((TrajectoryHabitNode x) => x.habitId), <String>[
      'c',
      'a',
      'b',
    ]);
    expect(
      TrajectoryHabitProjection.revision(first),
      TrajectoryHabitProjection.revision(
        nodes(habits.reversed.toList(), const <HabitOccurrenceEntity>[]),
      ),
    );
    expect(
      TrajectoryHabitProjection.revision(const <TrajectoryHabitNode>[]),
      isNull,
    );
  });

  test(
    'expected periods: daily H, weekly ceil(H / 7), monthly ceil(H / 30)',
    () {
      int periods(HabitCadence c, int h) =>
          TrajectoryHabitProjection.expectedPeriods(c, h);
      expect(
        <int>[
          periods(HabitCadence.daily, 7),
          periods(HabitCadence.daily, 30),
          periods(HabitCadence.daily, 90),
        ],
        <int>[7, 30, 90],
      );
      expect(
        <int>[
          periods(HabitCadence.weekly, 7),
          periods(HabitCadence.weekly, 30),
          periods(HabitCadence.weekly, 90),
        ],
        <int>[1, 5, 13],
      );
      expect(
        <int>[
          periods(HabitCadence.monthly, 7),
          periods(HabitCadence.monthly, 30),
          periods(HabitCadence.monthly, 90),
        ],
        <int>[1, 1, 3],
      );
    },
  );

  test('evidence lines list each habit as data', () {
    final HabitEntity walk = habit();
    final HabitEntity fresh = habit(
      id: 'fresh',
      title: 'Fresh',
      createdAt: daysAgo(1, 8),
    );
    final List<TrajectoryHabitNode> n = nodes(
      <HabitEntity>[walk, fresh],
      <HabitOccurrenceEntity>[
        for (int i = 1; i <= 28; i++) record(walk, daysAgo(i)),
      ],
    );
    expect(n.map(TrajectoryHabitProjection.evidenceLine), <String>[
      'habit=fresh:daily:not_enough_history:1/3:expected=7',
      'habit=walk:daily:enough:28/28:expected=7:check_ins=4-7-7',
    ]);
  });
}
