import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_v2_engine.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 21);
  SIV2GoalEvidence goal(String id, String title, [DateTime? date]) =>
      SIV2GoalEvidence(id: id, title: title, createdAt: now, targetDate: date);
  SIV2Query query(String text, {List<String> prior = const []}) =>
      SIV2Query.fromUserInput(
        rawText: text,
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
        priorUserTurns: prior,
      );
  SIV2EvidenceSnapshot snapshot(
    List<SIV2GoalEvidence> goals, {
    SIV2PersonContextEvidence? context,
    List<SIV2TaskEvidence> tasks = const [],
  }) => SIV2EvidenceSnapshot(
    accountScopeId: 'account:test',
    observedAt: now,
    tasks: tasks,
    goals: goals,
    milestones: const [],
    timeline: const [],
    personContext: context,
  );
  SIV2Response ask(String text, List<SIV2GoalEvidence> goals) =>
      const SIV2Engine().analyze(
        query: query(text),
        snapshot: snapshot(goals),
        now: now,
      );

  test('undated goals do not invent a date-based preference', () {
    final response = ask('Which goals need attention?', [
      goal('a', 'Grocery budget'),
      goal('b', 'Bicycle repair'),
    ]);
    expect(response.directAnswer, contains('are tied'));
    expect(response.directAnswer, isNot(contains('ranks ahead')));
    response.validate();
  });
  test('available-action wording returns a saved task instead of unsupported', () {
    for (final text in [
      'What can I do in five minutes before school pickup to review a bookkeeping example?',
      'What can I work on for 10 minutes?',
      'What can I do with an hour?',
      'What can I do next?',
      'I have five minutes before school pickup. What is one small bookkeeping action I can do now?',
      'What is a quick task I can do next?',
    ]) {
      final response = const SIV2Engine().analyze(
        query: query(text),
        snapshot: snapshot(
          [],
          tasks: [
            SIV2TaskEvidence(
              id: 'task',
              title: 'Review a bookkeeping example',
              createdAt: now,
              priority: 3,
            ),
          ],
        ),
        now: now,
      );
      expect(
        response.directAnswer,
        contains('For the next action'),
        reason: text,
      );
      expect(response.directAnswer, contains('Review a bookkeeping example'));
      response.validate();
    }
  });
  test(
    'weather and place questions do not become unrelated task schedules',
    () {
      for (final text in [
        'Will it rain tomorrow?',
        'What is the weather tomorrow?',
        'Forecast the weather this week.',
        'What can I do in New York?',
      ]) {
        final response = const SIV2Engine().analyze(
          query: query(text),
          snapshot: snapshot(
            [],
            tasks: [
              SIV2TaskEvidence(
                id: 'task',
                title: 'Review a bookkeeping example',
                createdAt: now,
                priority: 3,
              ),
            ],
          ),
          now: now,
        );
        expect(
          response.directAnswer,
          contains('SI cannot answer'),
          reason: text,
        );
        expect(
          response.recommendation,
          isNot(contains('Review a bookkeeping example')),
        );
      }
      expect(
        ask('Tell me about my weather preparation goal', [
          goal('g', 'Weather preparation'),
        ]).directAnswer,
        isNot(contains('SI cannot answer')),
      );
    },
  );
  test('matching title explains ordering even when its date is later', () {
    final response = ask('Compare grocery goals', [
      goal('a', 'Bicycle repair', now),
      goal('b', 'Grocery budget', now.add(const Duration(days: 3))),
    ]);
    expect(response.directAnswer, startsWith('"Grocery budget" ranks ahead'));
    expect(response.directAnswer, contains('title more closely matches'));
    expect(response.directAnswer, contains('dates did not decide'));
  });
  test(
    'equal relevance uses actual earlier date and acknowledges date ties',
    () {
      final dated = ask('Compare goals', [
        goal('a', 'Grocery budget', now),
        goal('b', 'Bicycle repair', now.add(const Duration(days: 3))),
      ]);
      expect(dated.directAnswer, contains('title relevance is tied'));
      expect(dated.directAnswer, contains('ranks ahead'));
      final tied = ask('Compare goals', [
        goal('a', 'Grocery budget', now),
        goal('b', 'Bicycle repair', now),
      ]);
      expect(tied.directAnswer, contains('are tied'));
    },
  );
  test('natural goal listing names records and bounds large collections', () {
    final response = ask(
      'List my goals.',
      List.generate(21, (i) => goal('g$i', 'Saved goal $i')),
    );
    expect(response.directAnswer, contains('21 saved goals'));
    expect(response.directAnswer, contains('Showing the first 20'));
    expect('\u2022'.allMatches(response.directAnswer), hasLength(20));
    expect(response.directAnswer, isNot(contains('cannot answer')));
    expect(
      response.recommendation,
      contains('Review the listed saved records'),
    );
    expect(ask('Show my goals', []).directAnswer, contains('No saved'));
  });
  test(
    'ordinary current-goal and have-records questions list saved evidence',
    () {
      for (final text in [
        'What are my current goals?',
        'What goals do I have?',
      ]) {
        expect(
          ask(text, [goal('g', 'Weekend bookkeeping')]).directAnswer,
          contains('Weekend bookkeeping'),
        );
        expect(query(text).requestsListing, isTrue);
      }
      final response = const SIV2Engine().analyze(
        query: query('What tasks do I have?'),
        snapshot: snapshot(
          [],
          tasks: [
            SIV2TaskEvidence(
              id: 'receipts',
              title: 'Sort grocery receipts',
              createdAt: now,
              priority: 3,
            ),
          ],
        ),
        now: now,
      );
      expect(response.directAnswer, contains('Sort grocery receipts'));
      expect(
        response.recommendation,
        contains('Review the listed saved records'),
      );
      expect(
        ask('What milestones do I have?', []).directAnswer,
        contains('No saved'),
      );
      expect(query('What milestones do I have?').requestsListing, isTrue);
      expect(
        query(
          'What are my current goals for the weather tomorrow?',
        ).requestsListing,
        isFalse,
      );
    },
  );
  test(
    'new explicit topic excludes prior relevance but short follow-ups retain it',
    () async {
      final seen = <String>[];
      final service = SIV2QueryService(
        readEvidence: (_) async => snapshot([goal('g', 'Grocery budget')]),
        readEvidenceForDecision: (_, text) async {
          seen.add(text);
          return snapshot([goal('g', 'Grocery budget')]);
        },
        clock: () => now,
      );
      const prior = ['I have five minutes for groceries.'];
      await service.analyze(query('List my goals.', prior: prior));
      await service.analyze(query('Why?', prior: prior));
      expect(seen.first, 'List my goals.');
      expect(seen.last, contains('five minutes'));
      expect(
        query('List my goals.', prior: prior).conversationText,
        contains('five minutes'),
      );
    },
  );
  test('user-reported sentence does not duplicate punctuation', () {
    final response = const SIV2Engine().analyze(
      query: query('What should I do next?'),
      now: now,
      snapshot: snapshot(
        [goal('g', 'Grocery budget')],
        context: SIV2PersonContextEvidence(
          observedAt: now,
          purposes: operationalPersonContextPurposes,
          signals: [
            SIV2PersonContextSignalEvidence(
              id: 'capacity',
              kind: PersonContextKind.presentCapacity,
              userReportedValue: 'I have five minutes.',
              source: PersonContextSource.userAuthored,
              purpose: PersonContextPurpose.decisionSupport,
              recordedAt: now,
              freshUntil: now.add(const Duration(hours: 1)),
              expiresAt: now.add(const Duration(hours: 1)),
            ),
          ],
          unknownKinds: const {},
        ),
      ),
    );
    expect(
      response.userReportedEvidence.single.text,
      contains('five minutes. This'),
    );
    expect(
      response.userReportedEvidence.single.text,
      isNot(contains('minutes..')),
    );
  });
}
