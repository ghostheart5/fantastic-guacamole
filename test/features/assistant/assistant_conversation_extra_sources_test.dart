import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/ai_chat_extra_sources_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
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
  });

  final List<HabitEntity> habits;
  final List<HabitOccurrenceEntity> occurrences;
  final List<TaskEntity>? tasks;
  final List<GoalEntity>? goals;
  final List<MilestoneEntity> milestones;
  final Future<List<HabitEntity>> Function()? habitReader;

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
    readTasks: () async => allTasks,
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
}) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    personalizationProfileProvider.overrideWith(_Consent.new),
    aiChatExtraSourcesAvailableProvider.overrideWithValue(switchOn),
    siV2ReadGatewayProvider.overrideWith(
      (ref) =>
          fixture.gateway(ref.watch(accountStorageScopeProvider).v2Namespace!),
    ),
    domainTaskRepositoryProvider.overrideWithValue(_Tasks(fixture.allTasks)),
    selectedPlanningNoteProvider.overrideWith((ref) async => null),
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
  _Tasks(this.records);
  final List<TaskEntity> records;
  @override
  Future<List<TaskEntity>> getAllTasks() async => records;
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
}) {
  final factory = container.read(conversationPacketFactoryProvider);
  const prompt = 'How is my week?';
  // The call every screen made before this change: no extra-source argument.
  if (extras == null) {
    return factory.build(
      surface: surface,
      prompt: prompt,
      history: const [],
      languageCode: 'en',
      sources: sources,
      entityFilter: entityFilter,
    );
  }
  return factory.build(
    surface: surface,
    prompt: prompt,
    history: const [],
    languageCode: 'en',
    sources: sources,
    entityFilter: entityFilter,
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

HabitEntity _habit(String id, String title) => HabitEntity(
  id: id,
  title: title,
  createdAt: DateTime.now().subtract(const Duration(days: 90)),
  description: 'PRIVATE habit note',
);

HabitOccurrenceEntity _checkIn(HabitEntity habit, int daysAgo) {
  final at = DateTime.now().subtract(Duration(days: daysAgo));
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
  final at = DateTime.now().subtract(Duration(days: daysAgo));
  return TaskEntity(
    id: id,
    title: title,
    description: 'PRIVATE task note',
    createdAt: at.subtract(const Duration(days: 3)),
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
          'currentStreak': 3,
        },
      ]);
      expect(context.containsKey('recentTasks'), isFalse);
      expect(context.containsKey('goalProgress'), isFalse);
      expect(context['selectedSources'], [
        'goals',
        'habits',
        'milestones',
        'tasks',
        'timeline',
      ]);

      final all = await _build(container, extras: _all);
      context = _context(all);
      final recent = (context['recentTasks'] as List)
          .cast<Map<String, Object?>>();
      expect(recent.map((r) => [r['title'], r['outcome']]), [
        ['Send invoice', 'completed'],
        ['Sort mail', 'skipped'],
      ]);
      expect(recent.first.keys.toSet(), {'title', 'outcome', 'at'});
      expect(context['goalProgress'], [
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
      expect((context['recentTasks'] as List).map((h) => (h as Map)['title']), [
        'Walk the dog',
      ]);
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
      for (final key in ['habits', 'recentTasks', 'goalProgress']) {
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
      for (final key in ['habits', 'recentTasks', 'goalProgress']) {
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
      for (final key in ['habits', 'recentTasks', 'goalProgress']) {
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
      for (final key in ['habits', 'recentTasks', 'goalProgress']) {
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
