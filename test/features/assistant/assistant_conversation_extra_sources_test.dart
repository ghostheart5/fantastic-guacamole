import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/api.dart' show SIState;
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/ai_chat_extra_sources_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The three optional extra sources of AI chat (habits, recent results, goal
// progress): off by default and behind a build switch; the paid packet is
// unchanged when they are off.

final _scope = AccountStorageScope.authenticated('synthetic-scope');

/// The packet the paid request carried before the extra sources existed, for
/// the fixture below, with the clock fields fixed. Captured by running the
/// code before this change.
const _pinnedBody =
    r'{"prompt":"How is my week?","history":[],"personality":"strategist","context":{"language":"en","nowLocal":"NOW","utcOffsetMinutes":0,"taskTimeZoneId":null,"mode":"answer","timeRange":"all","selectedSources":["goals","milestones","tasks","timeline"],"entityFilter":"","scenarioAssumption":"","evidenceRevision":"REVISION","tasks":[{"id":"grocery","title":"Grocery list","priority":3,"scheduledStart":null,"deadline":null,"goalId":"launch","description":"Milk, rice and vegetables for dinner.","estimatedDurationMinutes":45}],"goals":[{"id":"launch","title":"Launch","targetDate":null}],"milestones":[],"timeline":[],"omittedRecordCount":0,"unavailableSources":[],"surface":"si"},"maxTokens":1024,"allowExternalAi":true}';

final _tasks = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    description: 'Milk, rice and vegetables for dinner.',
    estimatedDuration: const Duration(minutes: 45),
    createdAt: DateTime.utc(2026, 8, 1),
    goalId: 'launch',
  ),
];

/// Everything the extra sources can read, for an account with some activity.
class _Fixture {
  _Fixture({
    this.habits = const [],
    this.occurrences = const [],
    this.tasks,
    this.goals,
    this.milestones = const [],
    this.habitReader,
    this.failTasks = false,
    this.failDetails = false,
  });

  final List<HabitEntity> habits;
  final List<HabitOccurrenceEntity> occurrences;
  final List<TaskEntity>? tasks;
  final List<GoalEntity>? goals;
  final List<MilestoneEntity> milestones;
  final Future<List<HabitEntity>> Function()? habitReader;
  final bool failTasks;
  final bool failDetails;

  List<TaskEntity> get allTasks => tasks ?? _tasks;
  List<GoalEntity> get allGoals =>
      goals ??
      [
        GoalEntity(
          id: 'launch',
          title: 'Launch',
          createdAt: DateTime.utc(2026, 8),
        ),
      ];

  SIV2ReadGateway gateway(String accountScopeId) => SIV2ReadGateway(
    accountScopeId: accountScopeId,
    readTasks: () async => failTasks ? throw StateError('tasks') : allTasks,
    readGoals: () async => allGoals,
    readMilestones: () async => milestones,
    readTimeline: () async => [],
    readHabits: habitReader ?? () async => habits,
    readHabitOccurrences: () async => occurrences,
  );
}

ProviderContainer _container(
  _Fixture fixture, {
  required bool switchOn,
  AccountStorageScope Function()? readScope,
  NoteEntity? note,
  ConsentedHumanContext? human,
}) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    personalizationProfileProvider.overrideWith(_Consent.new),
    aiChatExtraSourcesAvailableProvider.overrideWithValue(switchOn),
    conversationClockProvider.overrideWithValue(() => _now),
    siV2ReadGatewayProvider.overrideWith(
      (ref) =>
          fixture.gateway(ref.watch(accountStorageScopeProvider).v2Namespace!),
    ),
    domainTaskRepositoryProvider.overrideWithValue(
      _Tasks(fixture.allTasks, fail: fixture.failDetails),
    ),
    selectedPlanningNoteProvider.overrideWith((ref) async => note),
    if (human != null) consentedHumanContextProvider.overrideWithValue(human),
    for (final capability in [
      AssistantReleaseCapability.smartPlannerV2,
      AssistantReleaseCapability.siConsoleV2,
      AssistantReleaseCapability.safetyCritic,
    ])
      assistantReleaseDecisionProvider(capability).overrideWith(
        (ref) async => AssistantReleaseDecision(
          enabled: true,
          shadowEvaluationEnabled: false,
          cohort: AssistantReleaseCohort.internal,
          reasonCode: 'synthetic-test',
          accountDigest: 'test',
          capability: capability,
          configDigest: 'test',
        ),
      ),
  ],
);

class _Consent extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() =>
      const PersonalizationProfile(externalAiAllowed: true);
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-scope',
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _Tasks implements ITaskRepository {
  _Tasks(this.records, {this.fail = false});
  final List<TaskEntity> records;
  final bool fail;
  @override
  Future<List<TaskEntity>> getAllTasks() async =>
      fail ? throw StateError('details') : records;
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) => throw StateError('no');
  @override
  Future<void> deleteTask(String id) => throw StateError('no');
}

const _myPlan = {
  SIV2Source.tasks,
  SIV2Source.goals,
  SIV2Source.milestones,
  SIV2Source.timeline,
};

const _extraKeys = ['habits', 'recentTasksLast14Days', 'goalProgressAllTime'];

const _all = {
  ConversationExtraSource.habits,
  ConversationExtraSource.recentTasks,
  ConversationExtraSource.goalProgress,
};

Future<ConversationPacket> _build(
  ProviderContainer container, {
  Set<ConversationExtraSource>? extras,
  Set<SIV2Source> sources = _myPlan,
  ConversationSurface surface = ConversationSurface.si,
  String entityFilter = '',
  SIV2TimeRange range = SIV2TimeRange.all,
  String? selectedTaskId,
  List<Map<String, String>> history = const [],
  String prompt = 'How is my week?',
  SIV2Intent intent = SIV2Intent.answer,
}) {
  final factory = container.read(conversationPacketFactoryProvider);
  // The call every screen made before this change: no extra-source argument.
  if (extras == null) {
    return factory.build(
      surface: surface,
      prompt: prompt,
      history: history,
      languageCode: 'en',
      selectedTaskId: selectedTaskId,
      intent: intent,
      sources: sources,
      entityFilter: entityFilter,
      range: range,
    );
  }
  return factory.build(
    surface: surface,
    prompt: prompt,
    history: history,
    languageCode: 'en',
    selectedTaskId: selectedTaskId,
    intent: intent,
    sources: sources,
    entityFilter: entityFilter,
    range: range,
    extraSources: extras,
  );
}

/// The body with the clock fields fixed, as the pinned value is written. The
/// evidence revision is a hash that includes the moment of reading, so it is
/// fixed too; that it does not change with the new records is pinned in
/// si_v2_read_gateway_one_tap_test.dart.
String _fixedBody(ConversationPacket packet) {
  final body = jsonDecode(packet.serializedBody) as Map<String, dynamic>;
  final context = body['context'] as Map<String, dynamic>;
  context['nowLocal'] = 'NOW';
  context['utcOffsetMinutes'] = 0;
  context['evidenceRevision'] = 'REVISION';
  return jsonEncode(body);
}

Map<String, dynamic> _context(ConversationPacket packet) =>
    Map<String, dynamic>.from(packet.toJson()['context'] as Map);

/// The moment every request in this file is built at (see the clock override).
final _now = DateTime(2026, 8, 20, 12);

/// A local time on a calendar day before [_now], built from calendar fields
/// so a day with 23 or 25 hours changes nothing.
DateTime _daysAgo(int days, [int hour = 9]) =>
    DateTime(_now.year, _now.month, _now.day - days, hour);

HabitEntity _habit(String id, String title) => HabitEntity(
  id: id,
  title: title,
  createdAt: _daysAgo(90),
  description: 'PRIVATE habit note',
);

HabitOccurrenceEntity _checkIn(HabitEntity habit, int daysAgo) {
  final at = _daysAgo(daysAgo);
  return HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
    operationId: 'op-${habit.id}-$daysAgo',
    outcome: HabitOccurrenceOutcome.completed,
    recordedAt: at.toUtc(),
  );
}

TaskEntity _finished(
  String id,
  String title,
  int daysAgo, {
  bool skip = false,
}) {
  final at = _daysAgo(daysAgo);
  return TaskEntity(
    id: id,
    title: title,
    description: 'PRIVATE task note',
    createdAt: _daysAgo(daysAgo + 3),
    isCompleted: !skip,
    completedAt: skip ? null : at,
    isSkipped: skip,
    skippedAt: skip ? at : null,
    goalId: 'launch',
  );
}

void main() {
  group('paid packet with the extra sources off', () {
    // Habits and check-ins exist but are not asked for.
    _Fixture busy() {
      final walk = _habit('walk', 'Walk');
      return _Fixture(habits: [walk], occurrences: [_checkIn(walk, 1)]);
    }

    test('is byte-identical to the pinned value by default', () async {
      final container = _container(busy(), switchOn: true);
      addTearDown(container.dispose);
      final packet = await _build(container);
      expect(_fixedBody(packet), _pinnedBody);
    });

    test('is byte-identical when the build switch is off, even if extra '
        'sources are requested', () async {
      final container = _container(busy(), switchOn: false);
      addTearDown(container.dispose);
      final packet = await _build(container, extras: _all);
      expect(_fixedBody(packet), _pinnedBody);
    });

    test('finished tasks change nothing while the sources are off', () async {
      final fixture = _Fixture(
        tasks: [..._tasks, _finished('done', 'Finished thing', 1)],
      );
      final plain = _container(fixture, switchOn: true);
      final off = _container(fixture, switchOn: false);
      addTearDown(plain.dispose);
      addTearDown(off.dispose);
      expect(
        _fixedBody(await _build(off, extras: _all)),
        _fixedBody(await _build(plain)),
      );
    });

    test(
      'is byte-identical when the switch is on but none is chosen',
      () async {
        final container = _container(busy(), switchOn: true);
        addTearDown(container.dispose);
        final packet = await _build(container, extras: const {});
        expect(_fixedBody(packet), _pinnedBody);
      },
    );
  });

  group('paid packet with the extra sources on', () {
    test('carries exactly the chosen sources, with the fields shown', () async {
      final walk = _habit('walk', 'Walk');
      final fixture = _Fixture(
        habits: [walk],
        occurrences: [for (var i = 0; i < 3; i++) _checkIn(walk, i)],
        tasks: [
          ..._tasks,
          _finished('done', 'Send invoice', 2),
          _finished('skipped', 'Sort mail', 4, skip: true),
        ],
        milestones: [
          MilestoneEntity(
            id: 'm1',
            title: 'Draft',
            goalId: 'launch',
            createdAt: DateTime.utc(2026, 8),
            updatedAt: DateTime.utc(2026, 8),
            status: MilestoneStatus.completed,
          ),
        ],
      );
      final container = _container(fixture, switchOn: true);
      addTearDown(container.dispose);

      final packet = await _build(
        container,
        extras: {ConversationExtraSource.habits},
      );
      var context = _context(packet);
      expect(context['habits'], [
        {
          'title': 'Walk',
          'cadence': 'daily',
          'checkInsLast14Days': 3,
          'streakPeriods': 3,
        },
      ]);
      expect(context.containsKey('recentTasksLast14Days'), isFalse);
      expect(context.containsKey('goalProgressAllTime'), isFalse);
      expect(context['selectedSources'], [
        'goals',
        'habits',
        'milestones',
        'tasks',
        'timeline',
      ]);

      final all = await _build(container, extras: _all);
      context = _context(all);
      final recent = (context['recentTasksLast14Days'] as List)
          .cast<Map<String, Object?>>();
      expect(recent.map((r) => [r['title'], r['outcome']]), [
        ['Send invoice', 'completed'],
        ['Sort mail', 'skipped'],
      ]);
      expect(recent.first.keys.toSet(), {'title', 'outcome', 'at'});
      expect(context['goalProgressAllTime'], [
        {
          'title': 'Launch',
          'tasksDone': 1,
          'tasksOpen': 1,
          'milestonesDone': 1,
          'milestonesOpen': 0,
        },
      ]);
      // Nothing from a note, a description or an emotion is added.
      expect(all.serializedBody, isNot(contains('PRIVATE')));
      expect(context.containsKey('reportedEmotion'), isFalse);
      expect(context.containsKey('explicitlyAttachedNote'), isFalse);
      expect(context.containsKey('reportedEnergy'), isFalse);
    });

    test('the title filter applies to the extra sources too', () async {
      final container = _container(
        _Fixture(
          habits: [_habit('walk', 'Walk'), _habit('read', 'Read')],
          tasks: [
            ..._tasks,
            _finished('a', 'Walk the dog', 1),
            _finished('b', 'Pay rent', 1),
          ],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final context = _context(
        await _build(container, extras: _all, entityFilter: 'walk'),
      );
      expect((context['habits'] as List).map((h) => (h as Map)['title']), [
        'Walk',
      ]);
      expect(
        (context['recentTasksLast14Days'] as List).map(
          (h) => (h as Map)['title'],
        ),
        ['Walk the dog'],
      );
    });

    test('12 items per source and one size cap across all sources', () async {
      final container = _container(
        _Fixture(
          habits: [
            for (var i = 0; i < 20; i++) _habit('h$i', 'Habit number $i'),
          ],
          tasks: [
            ..._tasks,
            for (var i = 0; i < 30; i++)
              _finished('t$i', 'Done $i', 1 + i % 10),
          ],
          goals: [
            for (var i = 0; i < 15; i++)
              GoalEntity(
                id: 'g$i',
                title: 'Goal $i',
                createdAt: DateTime.utc(2026, 8),
              ),
          ],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(container, extras: _all);
      final context = _context(packet);
      for (final key in _extraKeys) {
        expect((context[key] as List).length, 12, reason: key);
      }
      // 8 habits, 18 recent results and 3 goal records did not fit, plus the 3
      // goals the existing Goals source leaves out: counted, not hidden.
      expect(context['omittedRecordCount'], 8 + 18 + 3 + 3);
      expect(packet.serializedBody.length, lessThanOrEqualTo(30000));
    });

    test('long titles are shortened and the whole context stays within the '
        'size cap by dropping from every source', () async {
      final long = 'x' * 400;
      final container = _container(
        _Fixture(
          habits: [for (var i = 0; i < 12; i++) _habit('h$i', '$long$i')],
          tasks: [
            ..._tasks,
            for (var i = 0; i < 12; i++) _finished('t$i', '$long$i', 1),
          ],
          goals: [
            for (var i = 0; i < 12; i++)
              GoalEntity(
                id: 'g$i',
                title: '$long$i',
                createdAt: DateTime.utc(2026, 8),
              ),
          ],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(container, extras: _all);
      final context = _context(packet);
      final withoutSurface = Map<String, dynamic>.of(context)
        ..remove('surface');
      expect(jsonEncode(withoutSurface).length, lessThanOrEqualTo(10000));
      expect(context['omittedRecordCount'], greaterThan(0));
      for (final key in _extraKeys) {
        for (final item in context[key] as List) {
          expect(((item as Map)['title'] as String).length, lessThan(160));
        }
      }
    });

    test('Just this chat sends none of them', () async {
      final container = _container(
        _Fixture(habits: [_habit('walk', 'Walk')]),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final context = _context(
        await _build(container, extras: _all, sources: const {}),
      );
      expect(context['contextScope'], 'chatOnly');
      expect(context['selectedSources'], isEmpty);
      for (final key in conversationExtraContextKeys) {
        expect(context.containsKey(key), isFalse);
      }
    });

    test('Choose a step never carries them', () async {
      final container = _container(
        _Fixture(habits: [_habit('walk', 'Walk')]),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final context = _context(
        await _build(
          container,
          extras: _all,
          surface: ConversationSurface.planner,
        ),
      );
      for (final key in conversationExtraContextKeys) {
        expect(context.containsKey(key), isFalse);
      }
    });

    test(
      'a source that cannot be read is named, never silently empty',
      () async {
        final container = _container(
          _Fixture(habitReader: () async => throw StateError('storage')),
          switchOn: true,
        );
        addTearDown(container.dispose);
        final context = _context(
          await _build(container, extras: {ConversationExtraSource.habits}),
        );
        expect(context['habits'], isEmpty);
        expect(context['unavailableSources'], ['habits']);
      },
    );

    test('another account\'s records never appear: a change of account '
        'while reading cancels the request', () async {
      var scope = _scope;
      late ProviderContainer container;
      final fixture = _Fixture(
        habitReader: () async {
          scope = AccountStorageScope.authenticated('other-account');
          container.invalidate(accountStorageScopeProvider);
          return [_habit('walk', 'Walk')];
        },
      );
      container = _container(fixture, switchOn: true, readScope: () => scope);
      addTearDown(container.dispose);
      await expectLater(
        _build(container, extras: {ConversationExtraSource.habits}),
        throwsA(
          isA<ConversationFailure>().having(
            (e) => e.code,
            'code',
            'authorization_changed',
          ),
        ),
      );
    });
  });

  group('what each source covers is in the request', () {
    _Fixture dated() => _Fixture(
      tasks: [
        ..._tasks,
        _finished('d0', 'Today task', 0),
        _finished('d2', 'Two days', 2),
        _finished('d5', 'Five days', 5, skip: true),
        _finished('d9', 'Nine days', 9),
        _finished('d40', 'Forty days', 40),
      ],
    );

    Future<Map<String, dynamic>> contextFor(SIV2TimeRange range) async {
      final container = _container(dated(), switchOn: true);
      addTearDown(container.dispose);
      return _context(await _build(container, extras: _all, range: range));
    }

    List<Object?> titles(Map<String, dynamic> context, String key) => [
      for (final item in context[key] as List) (item as Map)['title'],
    ];

    test(
      'recent results follow the selected dates, never past 14 days',
      () async {
        var context = await contextFor(SIV2TimeRange.today);
        expect(titles(context, 'recentTasksToday'), ['Today task']);
        expect(context.containsKey('recentTasksLast14Days'), isFalse);

        context = await contextFor(SIV2TimeRange.sevenDays);
        expect(titles(context, 'recentTasksLast7Days'), [
          'Today task',
          'Two days',
          'Five days',
        ]);

        for (final range in [SIV2TimeRange.thirtyDays, SIV2TimeRange.all]) {
          context = await contextFor(range);
          expect(titles(context, 'recentTasksLast14Days'), [
            'Today task',
            'Two days',
            'Five days',
            'Nine days',
          ]);
          expect(context['timeRange'], range.name);
          for (final other in ['recentTasksToday', 'recentTasksLast7Days']) {
            expect(context.containsKey(other), isFalse);
          }
        }
      },
    );

    test('goal progress is named all time and ignores the dates', () async {
      for (final range in SIV2TimeRange.values) {
        final context = await contextFor(range);
        final goal = (context['goalProgressAllTime'] as List).single as Map;
        // The 40 day old finished task still counts: all time.
        expect(goal['tasksDone'], 4);
        expect(goal['tasksOpen'], 1);
        expect(context.containsKey('goalProgress'), isFalse);
      }
    });

    test('a result carries a readable local date and time', () async {
      final context = await contextFor(SIV2TimeRange.sevenDays);
      final first = (context['recentTasksLast7Days'] as List).first as Map;
      expect(first['at'], '2026-08-20 09:00');
    });

    test(
      'a count that could not be read is left out, not sent as zero',
      () async {
        final container = _container(_Fixture(failTasks: true), switchOn: true);
        addTearDown(container.dispose);
        final context = _context(await _build(container, extras: _all));
        final goal = (context['goalProgressAllTime'] as List).single as Map;
        expect(goal.keys.toSet(), {
          'title',
          'milestonesDone',
          'milestonesOpen',
        });
        expect(
          context['unavailableSources'],
          containsAll(['recentTasks', 'goalProgress']),
        );
      },
    );

    test('the title filter reaches habits past the read limit', () async {
      final container = _container(
        _Fixture(
          habits: [for (var i = 10; i < 60; i++) _habit('h$i', 'Habit $i')],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final context = _context(
        await _build(
          container,
          extras: {ConversationExtraSource.habits},
          entityFilter: 'Habit 59',
        ),
      );
      expect(titles(context, 'habits'), ['Habit 59']);
    });

    test('the fullest request has 24 context keys, the server limit', () async {
      final container = _container(
        _Fixture(
          habits: [_habit('walk', 'Walk')],
          tasks: [..._tasks, _finished('a', 'Done', 1)],
          failDetails: true,
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(
        container,
        extras: _all,
        selectedTaskId: 'grocery',
        history: [
          {'role': 'user', 'content': 'x' * 2600},
        ],
      );
      final context = _context(packet);
      for (final key in [
        'taskDetailsUnavailable',
        'explicitlyAttachedTaskId',
        'historyClipped',
        ..._extraKeys,
      ]) {
        expect(context.containsKey(key), isTrue, reason: key);
      }
      // focusedTaskId appears only when the engine picks a focus task (not in
      // this fixture): counting it, the fullest request has 24 keys, which the
      // server accepts (24 is its limit).
      expect(
        context.length + (context.containsKey('focusedTaskId') ? 0 : 1),
        24,
      );
    });

    test('a stored request with extras is restored byte for byte', () async {
      final container = _container(
        _Fixture(habits: [_habit('walk', 'Walk')]),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(container, extras: _all);
      final restored = ConversationPacket.restore(
        surface: ConversationSurface.si,
        accountScope: packet.accountScope,
        requestId: packet.requestId,
        body: packet.serializedBody,
      );
      expect(restored.serializedBody, packet.serializedBody);
      expect(restored.toJson(), packet.toJson());
    });
  });

  group('limits the server enforces', () {
    // The context keys the fullest request can carry on each surface. A key
    // added later changes one of these sets and fails the test, so the new
    // key's place in the server's 24-key budget is decided on purpose.
    const chatKeys = {
      'language',
      'nowLocal',
      'utcOffsetMinutes',
      'taskTimeZoneId',
      'mode',
      'timeRange',
      'selectedSources',
      'entityFilter',
      'scenarioAssumption',
      'evidenceRevision',
      'taskDetailsUnavailable',
      'explicitlyAttachedTaskId',
      'focusedTaskId',
      'tasks',
      'goals',
      'milestones',
      'timeline',
      'omittedRecordCount',
      'unavailableSources',
      'habits',
      'recentTasksLast14Days',
      'goalProgressAllTime',
      'surface',
      'historyClipped',
    };
    // Choose a step: the note and energy and emotion instead of the extras.
    // The shortened-history marker is the one key left out at the limit.
    const plannerKeys = {
      'language',
      'nowLocal',
      'utcOffsetMinutes',
      'taskTimeZoneId',
      'mode',
      'timeRange',
      'selectedSources',
      'entityFilter',
      'scenarioAssumption',
      'evidenceRevision',
      'taskDetailsUnavailable',
      'explicitlyAttachedTaskId',
      'focusedTaskId',
      'tasks',
      'goals',
      'milestones',
      'timeline',
      'omittedRecordCount',
      'unavailableSources',
      'selectedNoteId',
      'explicitlyAttachedNote',
      'reportedEnergy',
      'reportedEmotion',
      'surface',
    };

    int depth(Object? value) => switch (value) {
      Map() => 1 + (value.values.map(depth).fold(0, (a, b) => a > b ? a : b)),
      List() => 1 + (value.map(depth).fold(0, (a, b) => a > b ? a : b)),
      _ => 0,
    };

    void expectServerLimits(ConversationPacket packet) {
      final body = jsonDecode(packet.serializedBody) as Map<String, dynamic>;
      final context = body['context'] as Map<String, dynamic>;
      expect(context.length, lessThanOrEqualTo(24));
      for (final entry in context.entries) {
        expect(entry.key.length, lessThanOrEqualTo(80));
        if (entry.value is List) {
          expect(
            (entry.value as List).length,
            lessThanOrEqualTo(12),
            reason: entry.key,
          );
        }
      }
      // The server counts the context itself at depth 0.
      expect(depth(context) - 1, lessThanOrEqualTo(4));
      expect(jsonEncode(context).length, lessThanOrEqualTo(12000));
      expect(packet.serializedBody.length, lessThanOrEqualTo(30000));
    }

    final longHistory = [
      {'role': 'user', 'content': 'x' * 2600},
    ];

    test('the fullest Chat request stays within them', () async {
      final container = _container(
        _Fixture(
          habits: [for (var i = 0; i < 14; i++) _habit('h$i', 'Habit $i')],
          tasks: [..._tasks, _finished('a', 'Done', 1)],
          failDetails: true,
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(
        container,
        extras: _all,
        selectedTaskId: 'grocery',
        history: longHistory,
        prompt: 'Does Grocery list conflict with an 8 PM store closing?',
        intent: SIV2Intent.findConflict,
      );
      expectServerLimits(packet);
      expect(_context(packet).keys.toSet(), chatKeys);
    });

    test('the fullest Choose a step request stays within them', () async {
      final container = _container(
        _Fixture(
          tasks: [..._tasks, _finished('a', 'Done', 1)],
          failDetails: true,
        ),
        switchOn: true,
        note: NoteEntity(
          id: 'n1',
          title: 'Note',
          body: 'Check the pantry.',
          createdAt: DateTime.utc(2026, 8),
          taskId: 'grocery',
        ),
        human: const ConsentedHumanContext(
          emotionAllowed: true,
          memoryAllowed: false,
          emotion: EmotionalState.fatigued,
          siState: SIState(),
        ),
      );
      addTearDown(container.dispose);
      final packet = await container
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.planner,
            prompt: 'Does Grocery list conflict with an 8 PM store closing?',
            intent: SIV2Intent.findConflict,
            history: longHistory,
            languageCode: 'en',
            selectedTaskId: 'grocery',
            attachedTaskOnly: false,
            reportedEnergy: 0.5,
          );
      expectServerLimits(packet);
      final context = _context(packet);
      expect(context.keys.toSet(), plannerKeys);
      // Without the limit this request would have 25 keys.
      expect(context.containsKey('historyClipped'), isFalse);
      // The shortened message says so in the history itself.
      expect(
        jsonEncode(packet.toJson()['history']),
        contains('[Earlier message shortened]'),
      );
    });

    test('a request with room keeps the shortened-history marker', () async {
      final container = _container(_Fixture(), switchOn: true);
      addTearDown(container.dispose);
      final packet = await _build(container, history: longHistory);
      expect(_context(packet)['historyClipped'], isTrue);
    });

    test('a request over the key limit is not built', () {
      expect(
        () => ConversationPacket(
          surface: ConversationSurface.si,
          accountScope: 'a',
          prompt: 'hi',
          history: const [],
          context: {for (var i = 0; i < 24; i++) 'key$i': i},
        ),
        throwsA(isA<ConversationFailure>()),
      );
    });
  });

  group('what does not fit is counted exactly', () {
    test(
      'exactly 40 and 41 habits, and more results than the old limit',
      () async {
        for (final count in [12, 40, 41]) {
          final container = _container(
            _Fixture(
              habits: [
                for (var i = 0; i < count; i++) _habit('h$i', 'Habit $i'),
              ],
            ),
            switchOn: true,
          );
          addTearDown(container.dispose);
          final context = _context(
            await _build(container, extras: {ConversationExtraSource.habits}),
          );
          expect(context['omittedRecordCount'], count - 12, reason: '$count');
        }
        final container = _container(
          _Fixture(
            tasks: [
              ..._tasks,
              for (var i = 0; i < 250; i++) _finished('t$i', 'Done $i', 1),
            ],
          ),
          switchOn: true,
        );
        addTearDown(container.dispose);
        final context = _context(
          await _build(
            container,
            extras: {ConversationExtraSource.recentTasks},
            range: SIV2TimeRange.sevenDays,
          ),
        );
        expect(context['omittedRecordCount'], 250 - 12);
      },
    );

    test('a completion dated after the request is not listed', () async {
      final container = _container(
        _Fixture(
          tasks: [
            ..._tasks,
            _finished('now', 'Finished this morning', 0),
            TaskEntity(
              id: 'future',
              title: 'Dated later today',
              createdAt: _daysAgo(2),
              isCompleted: true,
              completedAt: DateTime(2026, 8, 20, 18),
            ),
          ],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final context = _context(
        await _build(
          container,
          extras: {ConversationExtraSource.recentTasks},
          range: SIV2TimeRange.today,
        ),
      );
      expect(
        (context['recentTasksToday'] as List).map((t) => (t as Map)['title']),
        ['Finished this morning'],
      );
    });
  });

  group('reply receipt', () {
    test('counts what the request carried and round-trips', () async {
      final container = _container(
        _Fixture(
          habits: [_habit('walk', 'Walk')],
          tasks: [..._tasks, _finished('a', 'Done', 1)],
        ),
        switchOn: true,
      );
      addTearDown(container.dispose);
      final packet = await _build(container, extras: _all);
      final answer = ConversationAnswer(
        text: 'ok',
        model: 'm',
        credits: 5,
        remainingCredits: 20,
        requestId: packet.requestId,
      );
      final receipt = ConversationReplyReceipt.fromReply(packet, answer);
      expect(
        [receipt.habits, receipt.recentTasks, receipt.goalProgress],
        [1, 1, 1],
      );
      final back = ConversationReplyReceipt.decode(receipt.encode())!;
      expect(back.habits, 1);
      expect(back.recentTasks, 1);
      expect(back.goalProgress, 1);
    });

    test('a request without them keeps the receipt bytes it always had', () {
      const receipt = ConversationReplyReceipt(
        tasks: 2,
        creditsCharged: 5,
        remainingCredits: 20,
      );
      expect(receipt.toJson().keys, isNot(contains('habits')));
      expect(receipt.toJson(), hasLength(11));
      final back = ConversationReplyReceipt.decode(receipt.encode())!;
      expect([back.habits, back.recentTasks, back.goalProgress], [0, 0, 0]);
    });

    test('a receipt with an unknown or impossible count is not trusted', () {
      const receipt = ConversationReplyReceipt(
        creditsCharged: 5,
        remainingCredits: 20,
      );
      for (final extra in [
        {'habits': 0},
        {'habits': 13},
        {'habits': '2'},
        {'unknown': 1},
      ]) {
        expect(
          ConversationReplyReceipt.fromJson({...receipt.toJson(), ...extra}),
          isNull,
          reason: '$extra',
        );
      }
    });
  });
}
