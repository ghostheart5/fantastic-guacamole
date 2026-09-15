import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_v2_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 14, 20);

  SIV2Response ask(
    String text, {
    List<SIV2TaskEvidence> tasks = const <SIV2TaskEvidence>[],
    List<SIV2GoalEvidence> goals = const <SIV2GoalEvidence>[],
    SIV2TimeRange range = SIV2TimeRange.all,
  }) => const SIV2Engine().analyze(
    query: SIV2Query.fromUserInput(
      rawText: text,
      selectedIntent: SIV2Intent.answer,
      selectedSources: SIV2Source.values.toSet(),
      timeRange: range,
    ),
    snapshot: SIV2EvidenceSnapshot(
      accountScopeId: 'human-semantics',
      observedAt: now,
      tasks: tasks,
      goals: goals,
      milestones: const <SIV2MilestoneEvidence>[],
      timeline: const <SIV2TimelineEvidence>[],
    ),
    now: now,
  );

  SIV2TaskEvidence task(
    String id,
    String title, {
    int priority = 3,
    DateTime? dueDate,
    DateTime? scheduledFor,
  }) => SIV2TaskEvidence(
    id: id,
    title: title,
    createdAt: now.subtract(const Duration(days: 2)),
    priority: priority,
    dueDate: dueDate,
    scheduledFor: scheduledFor,
  );

  test(
    'explanation distinguishes a user deadline from an undated saved task',
    () {
      final response = ask(
        'My household grocery list is due tomorrow. Which saved task should I do now and why?',
        tasks: <SIV2TaskEvidence>[
          task('groceries', 'Plan the household grocery list', priority: 2),
        ],
      );
      expect(
        response.directAnswer,
        contains('Plan the household grocery list'),
      );
      expect(response.directAnswer, contains('priority is 2/5'));
      expect(response.directAnswer, contains('no saved due or scheduled time'));
      expect(response.directAnswer, isNot(contains('recorded due date')));
      response.validate();
    },
  );

  test('explanation uses an actual saved date when one exists', () {
    final response = ask(
      'Why does the grocery-list task rank here?',
      tasks: <SIV2TaskEvidence>[
        task(
          'groceries',
          'Plan the household grocery list',
          priority: 2,
          dueDate: now.add(const Duration(days: 2)),
        ),
      ],
    );
    expect(response.directAnswer, contains('saved timing'));
    expect(response.directAnswer, isNot(contains('no saved due')));
    response.validate();
  });

  test('an explicit exclusion can never become the recommendation', () {
    final response = ask(
      'What should I do next, not Submit tax return?',
      tasks: <SIV2TaskEvidence>[
        task('tax', 'Submit tax return', priority: 5),
        task('school', 'Email the school office', priority: 3),
      ],
    );

    expect(response.directAnswer, contains('Email the school office'));
    expect(response.recommendation, isNot(contains('Submit tax return')));
    expect(
      response.evidenceLinks.map((link) => link.entityId),
      isNot(contains('tax')),
    );
  });

  test('highest priority means priority before calendar order', () {
    final response = ask(
      'Which task has the highest priority?',
      tasks: <SIV2TaskEvidence>[
        task(
          'early',
          'Low priority early task',
          priority: 1,
          dueDate: now.add(const Duration(hours: 1)),
        ),
        task(
          'high',
          'High priority later task',
          priority: 5,
          dueDate: now.add(const Duration(days: 3)),
        ),
      ],
    );

    expect(response.directAnswer, contains('High priority later task'));
  });

  test(
    'today keeps a scheduled-today task even when its due date is later',
    () {
      final response = ask(
        'What is scheduled today?',
        range: SIV2TimeRange.today,
        tasks: <SIV2TaskEvidence>[
          task(
            'scheduled',
            'Call the clinic',
            scheduledFor: DateTime(2026, 9, 14, 21),
            dueDate: DateTime(2026, 9, 18),
          ),
        ],
      );

      expect(response.directAnswer, contains('Call the clinic'));
      expect(
        response.evidenceLinks.map((link) => link.entityId),
        contains('scheduled'),
      );
    },
  );

  test('requested seven-day delay stays seven days in every scenario', () {
    final response = ask(
      'What happens if I delay the clinic call for 7 days?',
      tasks: <SIV2TaskEvidence>[
        task(
          'clinic',
          'Clinic call',
          dueDate: now.add(const Duration(days: 1)),
        ),
      ],
    );

    expect(response.scenarios, isNotEmpty);
    expect(
      response.scenarios.map((scenario) => scenario.label),
      contains('Defer 7 days'),
    );
    expect(
      response.scenarios.map((scenario) => scenario.projectedEffect).join(' '),
      contains('7-day'),
    );
  });

  for (final text in <String>[
    '¿Qué necesita atención?',
    '¿Qué debería hacer después?',
  ]) {
    test(
      'Spanish welcome question is understood and answered in Spanish: $text',
      () {
        final response = ask(
          text,
          tasks: <SIV2TaskEvidence>[
            task('school', 'Llamar a la escuela', priority: 5),
          ],
        );

        expect(response.directAnswer, contains('Llamar a la escuela'));
        expect(response.directAnswer, isNot(contains('cannot')));
        expect(response.recommendation, contains('SI no cambió ningún dato'));
        expect(
          response.observedFacts.map((statement) => statement.text).join(' '),
          isNot(contains('matched the current lens')),
        );
      },
    );
  }

  test('unsupported questions contain no unrelated actionable sections', () {
    final response = ask(
      'What is the weather outside?',
      tasks: <SIV2TaskEvidence>[task('grocery', 'Sort grocery receipts')],
    );

    expect(response.scenarios, isEmpty);
    expect(response.conflicts, isEmpty);
    expect(response.calculations, isEmpty);
    expect(response.inferences, isEmpty);
    expect(response.recommendation, contains('planning question'));
  });

  test('available sources without relevant records are limited evidence', () {
    final response = ask('What needs attention?');

    expect(response.confidence.coveredSignals, 0);
    expect(response.confidence.strength, SIV2EvidenceStrength.limited);
    expect(response.confidence.freshness, SIV2Freshness.unavailable);
  });
}
