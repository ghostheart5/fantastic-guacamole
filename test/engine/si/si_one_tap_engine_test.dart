import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SIOneTapEngine engine = SIOneTapEngine();
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

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
  }) => engine.answer(
    question: q,
    snapshot: s,
    now: now,
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

  test(
    'improve my routine: keeps the steady habit, flags the one that slips',
    () {
      final SIOneTapAnswer a = ask(SIOneTapQuestion.improveRoutine, typical);
      expect(a.response.directAnswer, contains('2 habits'));
      expect(a.response.recommendation, contains('Keep "Walk"'));
      expect(
        a.response.recommendation,
        contains('"Read" is the one that slips'),
      );
      expect(a.response.recommendation, contains('Nothing was changed'));
      expect(a.offerAi, isTrue);
    },
  );

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
}
