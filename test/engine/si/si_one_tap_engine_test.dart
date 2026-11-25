import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SIOneTapEngine engine = SIOneTapEngine();
  // Local times: the answers read the person's local calendar day, so the tests
  // build local moments and never depend on the machine's time zone.
  final DateTime now = DateTime(2026, 8, 20, 12);

  SIV2EvidenceSnapshot snapshot({
    List<SIV2TaskEvidence> tasks = const <SIV2TaskEvidence>[],
    List<SIV2GoalEvidence> goals = const <SIV2GoalEvidence>[],
    List<SIV2HabitEvidence> habits = const <SIV2HabitEvidence>[],
    List<SIV2RecentTaskEvidence> recent = const <SIV2RecentTaskEvidence>[],
    List<SIV2MilestoneEvidence> milestones = const <SIV2MilestoneEvidence>[],
    List<SIV2TimelineEvidence> timeline = const <SIV2TimelineEvidence>[],
    Set<SIV2Source> unavailable = const <SIV2Source>{},
    bool habitsUnavailable = false,
  }) => SIV2EvidenceSnapshot(
    accountScopeId: 'account:test',
    observedAt: now,
    tasks: tasks,
    goals: goals,
    milestones: milestones,
    timeline: timeline,
    habits: habits,
    recentTasks: recent,
    unavailableSources: unavailable,
    habitsUnavailable: habitsUnavailable,
  );

  SIV2TaskEvidence task(
    String id,
    String title, {
    int priority = 3,
    DateTime? due,
    DateTime? scheduled,
    String? goalId,
  }) => SIV2TaskEvidence(
    id: id,
    title: title,
    createdAt: now.subtract(const Duration(days: 30)),
    priority: priority,
    dueDate: due,
    scheduledFor: scheduled,
    goalId: goalId,
  );

  SIV2HabitEvidence habit(
    String id,
    String title, {
    int checkIns = 0,
    int streak = 0,
    bool checkedIn = false,
    HabitCadence cadence = HabitCadence.daily,
    int ageDays = 60,
  }) => SIV2HabitEvidence(
    id: id,
    title: title,
    createdAt: now.subtract(Duration(days: ageDays)),
    cadence: cadence,
    targetCount: 1,
    checkInsInWindow: checkIns,
    currentStreak: streak,
    checkedInThisPeriod: checkedIn,
  );

  SIV2RecentTaskEvidence recentTask(
    String id,
    int daysAgo, {
    SIV2RecentTaskOutcome outcome = SIV2RecentTaskOutcome.completed,
  }) => SIV2RecentTaskEvidence(
    id: id,
    title: 'Done $id',
    outcome: outcome,
    at: now.subtract(Duration(days: daysAgo)),
  );

  final SIV2EvidenceSnapshot empty = snapshot();
  final SIV2EvidenceSnapshot typical = snapshot(
    tasks: <SIV2TaskEvidence>[
      task('t1', 'Write report', priority: 4, due: now),
      task(
        't2',
        'Call the bank',
        priority: 2,
        due: now.add(const Duration(days: 3)),
      ),
      task('t3', 'Tidy the desk'),
      task('t4', 'Draft the plan', goalId: 'g1', priority: 5),
    ],
    goals: <SIV2GoalEvidence>[
      SIV2GoalEvidence(
        id: 'g1',
        title: 'Launch the app',
        createdAt: now.subtract(const Duration(days: 40)),
        targetDate: now.add(const Duration(days: 20)),
        linkedTasksDone: 2,
        linkedTasksOpen: 1,
        milestonesDone: 1,
        milestonesOpen: 1,
      ),
    ],
    habits: <SIV2HabitEvidence>[
      habit('h1', 'Walk', checkIns: 12, streak: 4, checkedIn: true),
      habit('h2', 'Read', checkIns: 3, streak: 0),
    ],
    recent: <SIV2RecentTaskEvidence>[
      recentTask('a', 1),
      recentTask('b', 2),
      recentTask('c', 3),
      recentTask('d', 9),
      recentTask('e', 10),
      recentTask('f', 4, outcome: SIV2RecentTaskOutcome.skipped),
    ],
  );
  final SIV2EvidenceSnapshot behind = snapshot(
    tasks: <SIV2TaskEvidence>[
      task(
        'o1',
        'File taxes',
        priority: 5,
        due: now.subtract(const Duration(days: 9)),
      ),
      task(
        'o2',
        'Renew passport',
        priority: 3,
        due: now.subtract(const Duration(days: 2)),
      ),
      task('t3', 'Tidy the desk'),
    ],
    goals: <SIV2GoalEvidence>[
      SIV2GoalEvidence(
        id: 'g1',
        title: 'Get fit',
        createdAt: now.subtract(const Duration(days: 90)),
        targetDate: now.subtract(const Duration(days: 5)),
      ),
      SIV2GoalEvidence(
        id: 'g2',
        title: 'Learn Spanish',
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ],
    habits: <SIV2HabitEvidence>[habit('h1', 'Stretch')],
  );

  SIOneTapAnswer ask(
    SIOneTapQuestion q,
    SIV2EvidenceSnapshot s, {
    bool es = false,
    String? goalId,
    DateTime? at,
  }) => engine.answer(
    question: q,
    snapshot: s,
    now: at ?? now,
    isSpanish: es,
    goalId: goalId,
  );

  String everything(SIOneTapAnswer a) => a.response.toPlainText();

  group(
    'every question answers for every kind of account, in both languages',
    () {
      final Map<String, SIV2EvidenceSnapshot> accounts =
          <String, SIV2EvidenceSnapshot>{
            'empty': empty,
            'typical': typical,
            'overdue': behind,
          };
      for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
        for (final MapEntry<String, SIV2EvidenceSnapshot> account
            in accounts.entries) {
          for (final bool es in <bool>[false, true]) {
            test('${q.name} / ${account.key} / ${es ? 'es' : 'en'}', () {
              final SIOneTapAnswer a = ask(
                q,
                account.value,
                es: es,
                goalId: account.value.goals.isEmpty
                    ? null
                    : account.value.goals.first.id,
              );
              a.response.validate();
              expect(a.response.directAnswer, isNotEmpty);
              expect(a.response.recommendation, isNotEmpty);
              expect(a.response.query.rawText, q.label(isSpanish: es));
              // Plain statement: nothing is claimed as done by the assistant.
              expect(everything(a), isNot(contains('has been saved')));
              // The card's three parts are always there.
              expect(a.response.missingInformation, isNotEmpty);
              expect(a.response.confidence.requiredSignals, greaterThan(0));
              if (account.key == 'empty') {
                expect(a.response.observedFacts, isEmpty);
                expect(a.response.confidence.coveredSignals, 0);
                expect(
                  a.response.confidence.strength,
                  SIV2EvidenceStrength.limited,
                );
                expect(a.offerAddSomething, isTrue);
                expect(a.offerAi, isFalse);
              }
              if (es) {
                expect(
                  a.response.recommendation,
                  isNot(matches(RegExp(r'\bNothing was changed\b'))),
                );
              }
            });
          }
        }
      }
    },
  );

  test(
    'plan my day: orders overdue first, then priority, and says what is unknown',
    () {
      final SIOneTapAnswer a = ask(
        SIOneTapQuestion.planMyDay,
        snapshot(
          tasks: <SIV2TaskEvidence>[
            task('a', 'Low today', priority: 1, due: now),
            task(
              'b',
              'Late one',
              priority: 2,
              due: now.subtract(const Duration(days: 3)),
            ),
            task('c', 'High today', priority: 5, due: now),
            task('d', 'Someday'),
          ],
        ),
      );
      expect(a.response.directAnswer, startsWith('3 tasks need you today'));
      expect(
        a.response.directAnswer,
        contains('1 overdue and 2 due or planned'),
      );
      expect(a.response.recommendation, contains('Start with "Late one"'));
      expect(a.response.recommendation, contains('"High today"'));
      expect(
        a.response.missingInformation.join(' '),
        allOf(contains('not recorded'), contains('1 open task has no date')),
      );
      expect(a.offerAi, isFalse);
    },
  );

  test('plan my day: only habits and an empty day is still answered', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.planMyDay,
      snapshot(habits: <SIV2HabitEvidence>[habit('h', 'Walk')]),
    );
    expect(
      a.response.directAnswer,
      contains('No task is overdue or due today'),
    );
    expect(a.response.recommendation, contains('daily habits'));
    expect(
      a.response.observedFacts.map((s) => s.text).join(' '),
      contains('1 daily habit has no check-in yet today'),
    );
  });

  test("what's coming up: lists dated items in order, not overdue ones", () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.whatsComingUp,
      snapshot(
        tasks: <SIV2TaskEvidence>[
          task('a', 'Far', due: now.add(const Duration(days: 6))),
          task('b', 'Near', due: now.add(const Duration(days: 1))),
          task('c', 'Too far', due: now.add(const Duration(days: 20))),
          task('d', 'Late', due: now.subtract(const Duration(days: 1))),
          task('e', 'Undated'),
        ],
      ),
    );
    expect(a.response.directAnswer, startsWith('2 items are coming up'));
    final List<String> facts = a.response.observedFacts
        .map((SIV2Statement s) => s.text)
        .toList();
    expect(
      facts.indexWhere((t) => t.contains('Near')),
      lessThan(facts.indexWhere((t) => t.contains('Far'))),
    );
    expect(facts.join(' '), isNot(contains('Too far')));
    expect(facts.join(' '), isNot(contains('Late')));
    expect(
      a.response.missingInformation.join(' '),
      contains('1 open task has no date'),
    );
  });

  test('falling behind: names what is late and what waited longest', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.fallingBehind, behind);
    expect(a.response.directAnswer, contains('2 overdue tasks'));
    expect(a.response.directAnswer, contains('1 goal'));
    expect(a.response.directAnswer, contains('1 quiet habit'));
    expect(a.response.recommendation, contains('"File taxes"'));
    expect(a.response.recommendation, contains('waited longest'));
  });

  test('falling behind: a typical account is not told it is behind', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.fallingBehind, typical);
    expect(a.response.directAnswer, startsWith('Nothing I can read is behind'));
    expect(a.response.observedFacts, isEmpty);
  });

  test('a new habit is not called quiet before 14 days', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.fallingBehind,
      snapshot(
        tasks: <SIV2TaskEvidence>[task('t', 'Something')],
        habits: <SIV2HabitEvidence>[habit('h', 'Brand new', ageDays: 3)],
      ),
    );
    expect(a.response.directAnswer, startsWith('Nothing I can read is behind'));
  });

  group('help me reach this goal', () {
    test('reads progress only from what is linked', () {
      final SIOneTapAnswer a = ask(
        SIOneTapQuestion.reachGoal,
        typical,
        goalId: 'g1',
      );
      expect(
        a.response.directAnswer,
        'Goal "Launch the app": 2 of 3 linked tasks are done and 1 of 2 milestones.',
      );
      expect(a.response.recommendation, contains('"Draft the plan"'));
      expect(a.offerAi, isTrue);
      expect(a.offerAddSomething, isFalse);
      expect(
        a.response.missingInformation.join(' '),
        contains('only the tasks and milestones you linked'),
      );
    });

    test('a goal with nothing linked says progress cannot be told', () {
      final SIOneTapAnswer a = ask(
        SIOneTapQuestion.reachGoal,
        behind,
        goalId: 'g2',
      );
      expect(a.response.directAnswer, contains('Nothing is linked to it yet'));
      expect(a.response.directAnswer, isNot(contains('% ')));
      expect(a.offerAddSomething, isTrue);
      expect(
        a.response.missingInformation.join(' '),
        allOf(contains('no target date'), contains('cannot be told')),
      );
    });

    test('several goals and none chosen asks which one', () {
      final SIOneTapAnswer a = ask(SIOneTapQuestion.reachGoal, behind);
      expect(a.response.directAnswer, contains('2 active goals'));
      expect(a.response.recommendation, contains('choose a goal'));
    });

    test('a goal that is gone is said plainly', () {
      final SIOneTapAnswer a = ask(
        SIOneTapQuestion.reachGoal,
        typical,
        goalId: 'missing',
      );
      expect(a.response.directAnswer, contains('no longer saved'));
    });
  });

  test('improve my routine: a brand-new habit is too new to judge', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.improveRoutine,
      snapshot(habits: <SIV2HabitEvidence>[habit('h', 'New', ageDays: 1)]),
    );
    expect(a.response.recommendation, contains('a few more days'));
    expect(a.response.missingInformation.join(' '), contains('too new'));
  });

  test('explain my patterns: too little history says so', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.explainPatterns,
      snapshot(
        tasks: <SIV2TaskEvidence>[task('t', 'Something')],
        recent: <SIV2RecentTaskEvidence>[recentTask('a', 1)],
      ),
    );
    expect(a.response.directAnswer, contains('too little history'));
    expect(a.response.calculations, isEmpty);
    expect(
      a.response.missingInformation.join(' '),
      contains('at least 5 are needed'),
    );
  });

  test('explain my patterns: counts are real and not causes', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.explainPatterns, typical);
    expect(
      a.response.observedFacts.first.text,
      '5 tasks were finished and 1 skipped in the last 14 days.',
    );
    expect(a.response.missingInformation.join(' '), contains('not reasons'));
  });

  test('help me get back on track: one step, not a catch-up of everything', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.getBackOnTrack, behind);
    expect(
      a.response.recommendation,
      contains('just one thing first: "File taxes"'),
    );
    expect(a.offerAi, isTrue);
  });

  test('help me get back on track: nothing behind is said honestly', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.getBackOnTrack, typical);
    expect(a.response.directAnswer, contains('not behind on anything'));
    // Nothing to catch up on: no second paid step is offered.
    expect(a.offerAi, isFalse);
  });

  test('review my week: this week against the one before, with real counts', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.reviewWeek, typical);
    expect(
      a.response.directAnswer,
      'This week, 3 tasks were finished and 1 skipped: more than the week before (2).',
    );
    expect(
      a.response.missingInformation.join(' '),
      contains('counted over 14 days, not 7'),
    );
  });

  test('review my week: nothing finished is not a made-up comparison', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.reviewWeek,
      snapshot(tasks: <SIV2TaskEvidence>[task('t', 'Something')]),
    );
    expect(
      a.response.directAnswer,
      startsWith('No task was finished or skipped'),
    );
    expect(
      a.response.missingInformation.join(' '),
      contains('no week to compare'),
    );
  });

  test('a source that could not be read is named and lowers certainty', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.planMyDay,
      snapshot(
        tasks: <SIV2TaskEvidence>[task('t', 'Something', due: now)],
        habitsUnavailable: true,
      ),
    );
    expect(
      a.response.missingInformation.join(' '),
      contains('habits could not be read'),
    );
    expect(a.response.confidence.freshness, SIV2Freshness.aging);
  });

  test('Spanish answers are Spanish and keep the same numbers', () {
    final SIOneTapAnswer a = ask(SIOneTapQuestion.planMyDay, behind, es: true);
    expect(a.response.directAnswer, startsWith('2 tareas necesitan de ti hoy'));
    expect(a.response.recommendation, contains('Empieza con "File taxes"'));
    expect(a.response.recommendation, contains('No se cambió nada'));
    expect(
      a.response.missingInformation.join(' '),
      contains('cuánto tiempo tienes hoy'),
    );
  });

  test('no answer changes a record or claims that it did', () {
    for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
      for (final bool es in <bool>[false, true]) {
        final String text = everything(ask(q, typical, es: es, goalId: 'g1'));
        expect(text, isNot(matches(RegExp(r'\b(I|We) (saved|created|added)'))));
        expect(text, isNot(contains('Done.')));
      }
    }
  });

  // ---- whole-day deadlines (a date chosen without a time of day) ----------
  // Saved at local midnight. These build the instant a Madrid (UTC+2) or Los
  // Angeles (UTC-7) midnight would produce and pass the matching calendar day,
  // so they hold in any machine zone.
  SIV2TaskEvidence wholeDayTask(
    String id,
    String title,
    DateTime day, {
    bool madrid = true,
  }) => SIV2TaskEvidence(
    id: id,
    title: title,
    createdAt: DateTime(2026, 7, 1),
    priority: 3,
    dueDate: madrid
        ? DateTime.utc(day.year, day.month, day.day - 1, 22)
        : DateTime.utc(day.year, day.month, day.day, 7),
    dueDay: day,
  );
  final DateTime aug20 = DateTime(2026, 8, 20);

  for (final bool madrid in <bool>[true, false]) {
    group('a whole-day deadline owns its whole day '
        '(${madrid ? 'UTC+2' : 'UTC-7'})', () {
      final SIV2EvidenceSnapshot dueToday = snapshot(
        tasks: <SIV2TaskEvidence>[
          wholeDayTask('d', 'Pay rent', aug20, madrid: madrid),
        ],
      );

      test('00:00 on its day: due today, not overdue', () {
        final SIOneTapAnswer a = ask(
          SIOneTapQuestion.planMyDay,
          dueToday,
          at: DateTime(2026, 8, 20),
        );
        expect(
          a.response.directAnswer,
          '1 task needs you today: 0 overdue and 1 due or planned for today.',
        );
        expect(
          a.response.observedFacts.map((f) => f.text),
          contains('"Pay rent" · due today · priority 3/5'),
        );
      });

      test('23:59 on its day: still due today, nothing behind', () {
        final DateTime late = DateTime(2026, 8, 20, 23, 59);
        expect(
          ask(
            SIOneTapQuestion.planMyDay,
            dueToday,
            at: late,
          ).response.directAnswer,
          contains('0 overdue and 1 due'),
        );
        expect(
          ask(
            SIOneTapQuestion.fallingBehind,
            dueToday,
            at: late,
          ).response.directAnswer,
          startsWith('Nothing I can read is behind'),
        );
      });

      test('00:00 the next day: overdue by 1 day', () {
        final SIOneTapAnswer a = ask(
          SIOneTapQuestion.planMyDay,
          dueToday,
          at: DateTime(2026, 8, 21),
        );
        expect(a.response.directAnswer, contains('1 overdue and 0 due'));
        expect(
          a.response.observedFacts.map((f) => f.text),
          contains('"Pay rent" · overdue by 1 day · priority 3/5'),
        );
      });

      test("what's coming up still lists it on its day", () {
        final SIOneTapAnswer a = ask(
          SIOneTapQuestion.whatsComingUp,
          dueToday,
          at: DateTime(2026, 8, 20, 18),
        );
        expect(a.response.directAnswer, startsWith('1 item is coming up'));
      });

      test('Review my week does not count it overdue on its day', () {
        final SIOneTapAnswer a = ask(
          SIOneTapQuestion.reviewWeek,
          dueToday,
          at: DateTime(2026, 8, 20, 9),
        );
        expect(
          a.response.observedFacts.map((f) => f.text).join(' '),
          contains('0 open tasks are overdue and 1 is due'),
        );
      });
    });
  }

  test('a goal and a milestone due today are not late until the day ends', () {
    final SIV2EvidenceSnapshot s = snapshot(
      tasks: <SIV2TaskEvidence>[task('t', 'Something')],
      goals: <SIV2GoalEvidence>[
        SIV2GoalEvidence(
          id: 'g',
          title: 'Ship it',
          createdAt: DateTime(2026, 7, 1),
          targetDate: DateTime.utc(2026, 8, 19, 22),
          targetDay: aug20,
        ),
      ],
      milestones: <SIV2MilestoneEvidence>[
        SIV2MilestoneEvidence(
          id: 'm',
          title: 'Beta',
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
          completionPercent: 0,
          completed: false,
          archived: false,
          targetDate: DateTime.utc(2026, 8, 19, 22),
          targetDay: aug20,
        ),
      ],
    );
    expect(
      ask(
        SIOneTapQuestion.fallingBehind,
        s,
        at: DateTime(2026, 8, 20, 23, 59),
      ).response.directAnswer,
      startsWith('Nothing I can read is behind'),
    );
    final String next = ask(
      SIOneTapQuestion.fallingBehind,
      s,
      at: DateTime(2026, 8, 21),
    ).response.directAnswer;
    expect(next, contains('1 goal'));
    expect(next, contains('1 milestone'));
  });

  test('a plan for a past day does not make a later deadline due today', () {
    final SIV2EvidenceSnapshot s = snapshot(
      tasks: <SIV2TaskEvidence>[
        SIV2TaskEvidence(
          id: 'p',
          title: 'Plan then due',
          createdAt: DateTime(2026, 7, 1),
          priority: 3,
          scheduledFor: DateTime(2026, 8, 18, 9),
          dueDate: DateTime(2026, 8, 25, 12),
        ),
      ],
    );
    final SIOneTapAnswer a = ask(SIOneTapQuestion.planMyDay, s);
    expect(
      a.response.directAnswer,
      startsWith('No task is overdue or due today'),
    );
  });

  // ---- patterns -----------------------------------------------------------
  SIV2RecentTaskEvidence doneOn(String id, DateTime at) =>
      SIV2RecentTaskEvidence(
        id: id,
        title: 'T $id',
        outcome: SIV2RecentTaskOutcome.completed,
        at: at,
      );

  test('a tie between two days is not called a most active day', () {
    // Two Mondays, two Wednesdays and a Friday, all at 9:00.
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.explainPatterns,
      snapshot(
        recent: <SIV2RecentTaskEvidence>[
          doneOn('a', DateTime(2026, 8, 17, 9)),
          doneOn('b', DateTime(2026, 8, 10, 9)),
          doneOn('c', DateTime(2026, 8, 19, 9)),
          doneOn('d', DateTime(2026, 8, 12, 9)),
          doneOn('e', DateTime(2026, 8, 14, 9)),
        ],
      ),
    );
    final String text = everything(a);
    expect(text, isNot(contains('Monday')));
    expect(text, isNot(contains('Wednesday')));
    expect(
      a.response.directAnswer,
      '5 of 5 finished tasks were marked done in the morning.',
    );
    expect(
      a.response.missingInformation.join(' '),
      contains('when a task was marked done'),
    );
  });

  test('a clear single day is stated as a count, not a verdict', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.explainPatterns,
      snapshot(
        recent: <SIV2RecentTaskEvidence>[
          doneOn('a', DateTime(2026, 8, 18, 9)),
          doneOn('b', DateTime(2026, 8, 11, 14)),
          doneOn('c', DateTime(2026, 8, 18, 19)),
          doneOn('d', DateTime(2026, 8, 17, 9)),
          doneOn('e', DateTime(2026, 8, 14, 9)),
        ],
      ),
    );
    expect(
      a.response.directAnswer,
      startsWith('3 of 5 finished tasks were marked done on a Tuesday.'),
    );
    expect(everything(a), isNot(contains('most active')));
  });

  test('four finished tasks are too few for a day or a time', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.explainPatterns,
      snapshot(
        recent: <SIV2RecentTaskEvidence>[
          doneOn('a', DateTime(2026, 8, 18, 9)),
          doneOn('b', DateTime(2026, 8, 11, 9)),
          doneOn('c', DateTime(2026, 8, 18, 9)),
          doneOn('d', DateTime(2026, 8, 18, 9)),
          recentTask('s', 3, outcome: SIV2RecentTaskOutcome.skipped),
        ],
      ),
    );
    expect(
      a.response.calculations.where((c) => c.text.contains('marked done')),
      isEmpty,
    );
  });

  // ---- routine ------------------------------------------------------------
  const List<String> advice = <String>[
    'smaller',
    'less frequent',
    'Keep "',
    'Daily Rhythms',
    'Ritmos diarios',
    'más pequeño',
    'menos frecuente',
    'Mantén "',
  ];

  test('Improve my routine describes counts and never advises on a habit', () {
    for (final bool es in <bool>[false, true]) {
      final SIOneTapAnswer a = ask(
        SIOneTapQuestion.improveRoutine,
        snapshot(
          habits: <SIV2HabitEvidence>[
            habit('b', 'Take blood pressure pill', checkIns: 3),
            habit('a', 'Stretch', checkIns: 0),
          ],
        ),
        es: es,
      );
      for (final String phrase in advice) {
        expect(everything(a), isNot(contains(phrase)), reason: phrase);
      }
    }
  });

  test('Improve my routine names the most and fewest check-ins as counts', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.improveRoutine,
      snapshot(
        habits: <SIV2HabitEvidence>[
          habit('w', 'Walk', checkIns: 9),
          habit('r', 'Read', checkIns: 3),
        ],
      ),
    );
    expect(
      a.response.recommendation,
      'The records show the most check-ins on "Walk" (9 of 14) and the fewest on "Read" (3 of 14). Whether and how to change a habit is up to you. Nothing was changed.',
    );
  });

  test('habits that tie are not ranked', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.improveRoutine,
      snapshot(
        habits: <SIV2HabitEvidence>[
          habit('b', 'Beta', checkIns: 5),
          habit('a', 'Alpha', checkIns: 5),
        ],
      ),
    );
    expect(a.response.recommendation, contains('the same pattern'));
    expect(a.response.recommendation, isNot(contains('Alpha')));
  });

  test('a weekly habit is judged in weeks and a monthly one is not judged', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.improveRoutine,
      snapshot(
        habits: <SIV2HabitEvidence>[
          habit('w', 'Long run', checkIns: 2, cadence: HabitCadence.weekly),
          habit(
            'm',
            'Review budget',
            checkIns: 1,
            cadence: HabitCadence.monthly,
          ),
        ],
      ),
    );
    final String facts = a.response.observedFacts
        .map((f) => f.text)
        .join(' | ');
    expect(
      facts,
      contains('"Long run" · weekly · checked in in 2 of the last 2 weeks'),
    );
    expect(
      facts,
      contains('"Review budget" · monthly · 1 check-in in the last 14 days'),
    );
    expect(
      a.response.missingInformation.join(' '),
      contains('1 habit is too new'),
    );
  });

  test(
    'a habit whose frequency was just changed is judged from the change',
    () {
      // Created 60 days ago, frequency changed 4 days ago, no check-in since.
      final SIV2HabitEvidence edited = SIV2HabitEvidence(
        id: 'e',
        title: 'Edited',
        createdAt: now.subtract(const Duration(days: 60)),
        trackedSince: now.subtract(const Duration(days: 4)),
        cadence: HabitCadence.daily,
        targetCount: 1,
        checkInsInWindow: 0,
        currentStreak: 0,
        checkedInThisPeriod: false,
      );
      final SIV2EvidenceSnapshot s = snapshot(
        tasks: <SIV2TaskEvidence>[task('t', 'Something')],
        habits: <SIV2HabitEvidence>[edited],
      );
      expect(
        ask(SIOneTapQuestion.fallingBehind, s).response.directAnswer,
        startsWith('Nothing I can read is behind'),
      );
      expect(
        ask(
          SIOneTapQuestion.improveRoutine,
          s,
        ).response.observedFacts.first.text,
        contains('checked in on 0 of the last 5 days'),
      );
    },
  );

  // ---- pinned answers for a fixed account (English and Spanish) -----------
  test('every question is pinned in English and Spanish', () {
    String pin(SIOneTapQuestion q, bool es) {
      final SIOneTapAnswer a = ask(q, typical, es: es, goalId: 'g1');
      return '${a.response.directAnswer} || ${a.response.recommendation}';
    }

    const Map<SIOneTapQuestion, List<String>>
    expected = <SIOneTapQuestion, List<String>>{
      SIOneTapQuestion.planMyDay: <String>[
        '1 task needs you today: 0 overdue and 1 due or planned for today. || Start with "Write report" (due today). Nothing was changed.',
        '1 tarea necesita de ti hoy: 0 vencidas y 1 para hoy. || Empieza con "Write report" (vence hoy). No se cambió nada.',
      ],
      SIOneTapQuestion.whatsComingUp: <String>[
        '2 items are coming up in the next 7 days. The nearest is "Write report" · due today. || Look at "Write report" · due today first. Nothing was changed.',
        '2 elementos vienen en los próximos 7 días. Lo más cercano es "Write report" · vence hoy. || Mira primero "Write report" · vence hoy. No se cambió nada.',
      ],
      SIOneTapQuestion.fallingBehind: <String>[
        'Nothing I can read is behind: no task is overdue, no goal or milestone is past its date, and no habit has gone quiet. || Keep your current pace. Nothing was changed.',
        'Nada de lo que puedo leer va atrasado: ninguna tarea está vencida, ninguna meta ni hito pasó su fecha y ningún hábito está inactivo. || Mantén tu ritmo actual. No se cambió nada.',
      ],
      SIOneTapQuestion.reachGoal: <String>[
        'Goal "Launch the app": 2 of 3 linked tasks are done and 1 of 2 milestones. || Take the next step on "Draft the plan" (no date). Nothing was changed.',
        'Meta "Launch the app": 2 de 3 tareas vinculadas están hechas y 1 de 2 hitos. || Da el siguiente paso en "Draft the plan" (sin fecha). No se cambió nada.',
      ],
      SIOneTapQuestion.improveRoutine: <String>[
        'You have 2 habits. Over the last 14 days, 2 have a check-in and 0 have none. || The records show the most check-ins on "Walk" (12 of 14) and the fewest on "Read" (3 of 14). Whether and how to change a habit is up to you. Nothing was changed.',
        'Tienes 2 hábitos. En los últimos 14 días, 2 tienen registros y 0 no tienen. || Los registros muestran la mayor cantidad en "Walk" (12 de 14) y la menor en "Read" (3 de 14). Si cambiar un hábito y cómo, lo decides tú. No se cambió nada.',
      ],
      SIOneTapQuestion.explainPatterns: <String>[
        '5 of 5 finished tasks were marked done in the afternoon. || Use this as a hint when you plan, and keep tracking. Nothing was changed.',
        '5 de 5 tareas terminadas se marcaron como hechas por la tarde. || Úsalo como pista al planear y sigue registrando. No se cambió nada.',
      ],
      SIOneTapQuestion.getBackOnTrack: <String>[
        'You are not behind on anything I can read: no task is overdue, no goal is past its date and no habit has gone quiet. || There is nothing to catch up on. Keep going at your own pace. Nothing was changed.',
        'No estás atrasado en nada que pueda leer: ninguna tarea está vencida, ninguna meta pasó su fecha y ningún hábito está inactivo. || No hay nada que recuperar. Sigue a tu ritmo. No se cambió nada.',
      ],
      SIOneTapQuestion.reviewWeek: <String>[
        'This week, 3 tasks were finished and 1 skipped: more than the week before (2). || Nothing is overdue. Next week has 2 items with a date. Nothing was changed.',
        'Esta semana se terminaron 3 tareas y se omitieron 1: más que la semana anterior (2). || No hay nada vencido. La próxima semana tiene 2 elementos con fecha. No se cambió nada.',
      ],
    };
    for (final MapEntry<SIOneTapQuestion, List<String>> e in expected.entries) {
      expect(pin(e.key, false), e.value[0], reason: '${e.key.name} en');
      expect(pin(e.key, true), e.value[1], reason: '${e.key.name} es');
    }
  });

  test('empty-account answers are pinned', () {
    expect(
      ask(SIOneTapQuestion.planMyDay, empty).response.directAnswer,
      'You have no tasks, goals or habits saved yet, so there is nothing to plan today.',
    );
    expect(
      ask(SIOneTapQuestion.reachGoal, empty).response.directAnswer,
      'You have no active goal yet, so there is nothing to work toward.',
    );
    expect(
      ask(
        SIOneTapQuestion.improveRoutine,
        empty,
        es: true,
      ).response.directAnswer,
      'Todavía no tienes hábitos guardados, así que no hay una rutina que mejorar.',
    );
    for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
      expect(ask(q, empty).response.observedFacts, isEmpty, reason: q.name);
    }
  });

  test('the week review splits the 14 days at 7 days', () {
    final SIOneTapAnswer a = ask(
      SIOneTapQuestion.reviewWeek,
      snapshot(
        tasks: <SIV2TaskEvidence>[task('t', 'Open')],
        recent: <SIV2RecentTaskEvidence>[
          recentTask('far', 13),
          recentTask('edge', 7),
          recentTask('week', 6),
        ],
      ),
    );
    // 6 days ago is this week; 7 and 13 days ago are the week before.
    expect(
      a.response.directAnswer,
      'This week, 1 task was finished and 0 skipped: fewer than the week before (2).',
    );
  });
}
