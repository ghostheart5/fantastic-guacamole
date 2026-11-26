import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_v2_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SIV2Response ask({
    required DateTime now,
    required List<DateTime> targets,
    String question = 'Which goals are overdue today?',
    SIV2TimeRange range = SIV2TimeRange.all,
    List<SIV2TaskEvidence> tasks = const [],
    List<SIV2MilestoneEvidence> milestones = const [],
  }) => const SIV2Engine().analyze(
    now: now.toUtc(), // The read gateway transports timestamps as UTC.
    query: SIV2Query.fromUserInput(
      rawText: question,
      selectedIntent: SIV2Intent.answer,
      selectedSources: {
        SIV2Source.goals,
        SIV2Source.tasks,
        SIV2Source.milestones,
      },
      timeRange: range,
    ),
    snapshot: SIV2EvidenceSnapshot(
      accountScopeId: 'calendar-regression',
      observedAt: now.toUtc(),
      goals: [
        for (var i = 0; i < targets.length; i++)
          SIV2GoalEvidence(
            id: 'g$i',
            title: 'Family plan $i',
            createdAt: DateTime(2026, 9, 1),
            targetDate: targets[i].toUtc(),
          ),
      ],
      tasks: tasks,
      milestones: milestones,
      timeline: const [],
    ),
  );

  for (final hour in [0, 12, 23]) {
    test('goal due today stays current at local hour $hour', () {
      final response = ask(
        now: DateTime(2026, 9, 13, hour, 59),
        targets: [DateTime(2026, 9, 13), DateTime(2026, 9, 14)],
      );
      expect(response.directAnswer, contains('target 2026-09-13, due today'));
      expect(response.directAnswer, isNot(contains('now past')));
      expect(
        response.calculations.map((s) => s.text),
        contains('0 matched goals are past the recorded target date.'),
      );
      response.validate();
    });
  }

  test(
    'only prior local dates count overdue; timed tasks retain their time',
    () {
      final now = DateTime(2026, 9, 13, 23, 59);
      final response = ask(
        now: now,
        targets: [
          DateTime(2026, 9, 12),
          DateTime(2026, 9, 13),
          DateTime(2026, 9, 14),
        ],
        tasks: [
          SIV2TaskEvidence(
            id: 't',
            title: 'Call school',
            createdAt: now,
            priority: 3,
            dueDate: DateTime(2026, 9, 13, 15).toUtc(),
          ),
        ],
      );
      expect(
        response.calculations.map((s) => s.text),
        contains('1 matched goal is past the recorded target date.'),
      );
      expect(
        response.calculations.map((s) => s.text),
        contains('1 matched task is past the recorded due date.'),
      );
      expect(response.directAnswer, contains('target 2026-09-12, now past'));
      response.validate();
    },
  );

  test('today lens follows local calendar even late in the UTC day', () {
    final response = ask(
      now: DateTime(2026, 9, 13, 23, 59),
      targets: [DateTime(2026, 9, 13), DateTime(2026, 9, 14)],
      range: SIV2TimeRange.today,
    );
    expect(
      response.observedFacts.map((s) => s.text),
      contains('1 active goal matched the selected information.'),
    );
  });

  test('same calendar target dates tie despite stored time components', () {
    final response = ask(
      now: DateTime(2026, 9, 13, 15),
      targets: [DateTime(2026, 9, 13), DateTime(2026, 9, 13, 23)],
      question: 'Compare goals',
    );
    expect(response.directAnswer, contains('are tied'));
  });

  test('task on goal target day does not cross the goal deadline', () {
    final now = DateTime(2026, 9, 13, 12);
    final response = ask(
      now: now,
      targets: [DateTime(2026, 9, 13)],
      tasks: [
        SIV2TaskEvidence(
          id: 'same-day',
          title: 'Pack school bag',
          createdAt: now,
          priority: 3,
          goalId: 'g0',
          dueDate: DateTime(2026, 9, 13, 18).toUtc(),
        ),
        SIV2TaskEvidence(
          id: 'next-day',
          title: 'Buy supplies',
          createdAt: now,
          priority: 3,
          goalId: 'g0',
          dueDate: DateTime(2026, 9, 14).toUtc(),
        ),
      ],
    );
    expect(
      response.conflicts.map((c) => c.conflictId),
      isNot(contains('task-after-goal:same-day:g0')),
    );
    expect(
      response.conflicts.map((c) => c.conflictId),
      contains('task-after-goal:next-day:g0'),
    );
  });

  test('goal becomes overdue at the following local midnight', () {
    final response = ask(
      now: DateTime(2026, 9, 14),
      targets: [DateTime(2026, 9, 13)],
    );
    expect(
      response.calculations.map((s) => s.text),
      contains('1 matched goal is past the recorded target date.'),
    );
  });

  test('milestone conflict respects the full linked goal target day', () {
    final now = DateTime(2026, 9, 13, 12);
    final response = ask(
      now: now,
      targets: [DateTime(2026, 9, 13)],
      milestones: [
        for (final day in [13, 14])
          SIV2MilestoneEvidence(
            id: 'm$day',
            title: 'Prepare supplies $day',
            createdAt: now,
            updatedAt: now,
            completionPercent: 0,
            completed: false,
            archived: false,
            goalId: 'g0',
            targetDate: DateTime(2026, 9, day, 18).toUtc(),
          ),
      ],
    );
    expect(
      response.conflicts.map((c) => c.conflictId),
      isNot(contains('milestone-after-goal:m13:g0')),
    );
    expect(
      response.conflicts.map((c) => c.conflictId),
      contains('milestone-after-goal:m14:g0'),
    );
  });

  test(
    'deferral landing on goal day stays within target; next day crosses',
    () {
      final now = DateTime(2026, 9, 12, 12);
      for (final taskDay in [12, 13]) {
        final response = ask(
          now: now,
          targets: [DateTime(2026, 9, 13)],
          tasks: [
            SIV2TaskEvidence(
              id: 't',
              title: 'Pack school bag',
              priority: 3,
              createdAt: now,
              goalId: 'g0',
              dueDate: DateTime(2026, 9, taskDay, 18).toUtc(),
            ),
          ],
        );
        final deferral = response.scenarios.singleWhere(
          (s) => s.kind == SIV2ScenarioKind.deferOneDay,
        );
        expect(
          deferral.projectedEffect,
          contains(
            taskDay == 12
                ? 'without crossing a visible goal target'
                : 'crosses the linked goal target date',
          ),
        );
      }
    },
  );

  // I3: one definition of a past deadline, shared with the one-tap answers.
  test('a timed deadline at 00:00 UTC is past from that moment, not a whole '
      'day', () {
    final now = DateTime.utc(2026, 9, 17, 0, 30);
    final response = ask(
      now: now,
      targets: const [],
      question: 'Which tasks are overdue?',
      tasks: [
        SIV2TaskEvidence(
          id: 't',
          title: 'Return the form',
          createdAt: DateTime.utc(2026, 9, 1),
          priority: 3,
          // 5 pm in Los Angeles in summer: a time, not a whole day.
          dueDate: DateTime.utc(2026, 9, 17),
        ),
      ],
    );
    expect(
      response.calculations.map((s) => s.text),
      contains('1 matched task is past the recorded due date.'),
    );
    response.validate();
  });

  test('a goal is judged by its saved calendar day', () {
    final now = DateTime(2026, 9, 17, 12);
    final response = const SIV2Engine().analyze(
      now: now.toUtc(),
      query: SIV2Query.fromUserInput(
        rawText: 'Which goals are overdue today?',
        selectedIntent: SIV2Intent.answer,
        selectedSources: {SIV2Source.goals},
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: SIV2EvidenceSnapshot(
        accountScopeId: 'calendar-regression',
        observedAt: now.toUtc(),
        goals: [
          SIV2GoalEvidence(
            id: 'g',
            title: 'Family plan',
            createdAt: DateTime(2026, 9, 1),
            targetDate: DateTime(2026, 9, 20, 12).toUtc(),
            targetDay: DateTime(2026, 9, 16),
          ),
        ],
        tasks: const [],
        milestones: const [],
        timeline: const [],
      ),
    );
    expect(
      response.calculations.map((s) => s.text),
      contains('1 matched goal is past the recorded target date.'),
    );
  });

  test('N10: a goal target with a time at 00:00 UTC is read on its local day '
      'in the label, the range and the count alike', () {
    final target = DateTime.utc(2026, 9, 17);
    final local = target.toLocal();
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final response = ask(
      now: DateTime(local.year, local.month, local.day, 23, 30),
      targets: [target],
      range: SIV2TimeRange.today,
    );
    expect(
      response.observedFacts.map((s) => s.text),
      contains('1 active goal matched the selected information.'),
    );
    expect(response.directAnswer, contains('target ${day(local)}, due today'));
    expect(
      response.calculations.map((s) => s.text),
      contains('0 matched goals are past the recorded target date.'),
    );
  });
}
