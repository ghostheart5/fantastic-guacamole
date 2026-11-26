import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
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
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The optional extra information in AI chat (habits, recent results, goal
// progress): hidden unless the build switch is on, off until chosen, and what
// the review shows is what the request carries.

final _scope = AccountStorageScope.authenticated('synthetic-scope');

// One fixed moment for every fixture and for the request (see the clock
// override), built from calendar fields so a day change cannot move it.
final _now = DateTime(2026, 8, 20, 12);
DateTime _daysAgo(int days) =>
    DateTime(_now.year, _now.month, _now.day - days, 9);
final _walk = HabitEntity(
  id: 'walk',
  title: 'Evening walk',
  createdAt: _daysAgo(90),
);
final _tasks = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    createdAt: DateTime.utc(2026, 8, 1),
    goalId: 'launch',
  ),
  TaskEntity(
    id: 'done',
    title: 'Send invoice',
    createdAt: _daysAgo(6),
    isCompleted: true,
    completedAt: _daysAgo(2),
    goalId: 'launch',
  ),
];

SIV2ReadGateway _gatewayFor(String? scope) => SIV2ReadGateway(
  accountScopeId: scope!,
  readTasks: () async => _tasks,
  readGoals: () async => [
    GoalEntity(id: 'launch', title: 'Launch', createdAt: DateTime.utc(2026, 8)),
  ],
  readMilestones: () async => [],
  readTimeline: () async => [],
  readHabits: () async => [_walk],
  readHabitOccurrences: () async => [
    for (var i = 0; i < 3; i++)
      HabitOccurrenceEntity(
        habitId: _walk.id,
        occurrenceKey: RhythmPlanningContext.occurrenceKey(_walk, _daysAgo(i)),
        operationId: 'op-$i',
        outcome: HabitOccurrenceOutcome.completed,
        recordedAt: _daysAgo(i).toUtc(),
      ),
  ],
);

const _habitsChip = Key('conversation-extra-habits');
const _recentChip = Key('conversation-extra-recentTasks');
const _goalChip = Key('conversation-extra-goalProgress');
const _row = Key('conversation-extra-sources');
const _chatOnly = Key('conversation-scope-chat-only');

ProviderContainer _setup(
  List<Map<String, dynamic>> sent, {
  required bool switchOn,
  AccountStorageScope Function()? readScope,
}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(
      SecureStore(backend: InMemorySecureStoreBackend()),
    ),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    aiChatExtraSourcesAvailableProvider.overrideWithValue(switchOn),
    conversationClockProvider.overrideWithValue(() => _now),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue((body) async {
      sent.add(body);
      // Stop after the quote request: these tests only read what is sent.
      throw StateError('No reply in this test');
    }),
    siV2ReadGatewayProvider.overrideWith(
      (ref) => _gatewayFor(ref.watch(accountStorageScopeProvider).v2Namespace),
    ),
    siV2PersonContextRevisionProvider.overrideWithValue('fixture-revision'),
    siV2EvidenceSnapshotProvider.overrideWith(
      (ref) => _gatewayFor(
        ref.watch(accountStorageScopeProvider).v2Namespace,
      ).read(observedAt: _now),
    ),
    domainTaskRepositoryProvider.overrideWithValue(_Tasks()),
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

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const [
          ChronoSparkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AssistantConversationScreen(
          surface: ConversationSurface.si,
          onLocalTools: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 60; i++) {
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

/// Taps send, waits for the review and returns its text. [accept] then sends,
/// which asks for the price once (the transport records it and stops).
Future<String> _review(
  WidgetTester tester,
  String prompt, {
  bool accept = true,
  bool spanish = false,
}) async {
  await tester.enterText(find.byKey(const Key('conversation-input')), prompt);
  await tester.tap(find.byKey(const Key('conversation-send')));
  await _waitFor(
    tester,
    find.text(
      spanish ? 'Revisa lo que recibirá la IA' : 'Review what AI will receive',
    ),
  );
  final preview = tester
      .widgetList<SelectableText>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SelectableText),
        ),
      )
      .map((widget) => widget.data ?? widget.textSpan!.toPlainText())
      .join('\n');
  if (accept) {
    await tester.tap(find.text(spanish ? 'Enviar' : 'Send'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  return preview;
}

/// Scrolls the conversation until [finder] is built, then makes it visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  for (final step in [180.0, -180.0]) {
    if (finder.evaluate().isNotEmpty) break;
    try {
      await tester.scrollUntilVisible(
        finder,
        step,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    } on StateError {
      // Not in this direction: try the other one.
    }
  }
  await Scrollable.ensureVisible(tester.element(finder));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _context(Map<String, dynamic> body) =>
    Map<String, dynamic>.from(body['context'] as Map);

bool _on(WidgetTester tester, Key key) =>
    tester.widget<FilterChip>(find.byKey(key)).selected;

void main() {
  testWidgets('with the build switch off the choices do not exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, switchOn: false);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    expect(find.byKey(_row), findsNothing);
    expect(find.byKey(_habitsChip), findsNothing);
    final preview = await _review(tester, 'How are my habits going?');
    final context = _context(sent.single);
    for (final key in conversationExtraContextKeys) {
      expect(context.containsKey(key), isFalse);
    }
    expect(preview, isNot(contains('Evening walk')));
    expect(preview, contains('Sources: Tasks, Goals, Milestones, Schedule'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'with the switch on all three start off and a default request carries none',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <Map<String, dynamic>>[];
      final container = _setup(sent, switchOn: true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      for (final key in [_habitsChip, _recentChip, _goalChip]) {
        expect(find.byKey(key).hitTestable(), findsOneWidget);
        expect(_on(tester, key), isFalse);
      }
      final preview = await _review(tester, 'How are my habits going?');
      final context = _context(sent.single);
      for (final key in conversationExtraContextKeys) {
        expect(context.containsKey(key), isFalse);
      }
      expect(context['selectedSources'], [
        'goals',
        'milestones',
        'tasks',
        'timeline',
      ]);
      expect(preview, isNot(contains('Evening walk')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'choosing them shows the preview again; it lists exactly what is sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <Map<String, dynamic>>[];
      final container = _setup(sent, switchOn: true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      // A first request with nothing extra: the preview is accepted.
      await _review(tester, 'How are my habits going?');
      expect(sent, hasLength(1));

      for (final key in [_habitsChip, _recentChip, _goalChip]) {
        await tester.tap(find.byKey(key));
        await tester.pump();
        expect(_on(tester, key), isTrue);
      }
      // The selection changed, so the full preview opens by itself again.
      final preview = await _review(tester, 'How are my habits going?');
      expect(sent, hasLength(2));
      final context = _context(sent.last);

      expect(
        preview,
        contains(
          'Sources: Tasks, Goals, Milestones, Schedule, Habits, Recent results, Goal progress',
        ),
      );
      // Habits: every field of every record sent is a line in the review.
      final habits = (context['habits'] as List).cast<Map<String, Object?>>();
      expect(habits, hasLength(1));
      expect(
        preview,
        contains('Habits (check-ins: last 14 days)\nTitle: Evening walk'),
      );
      expect(preview, contains('Repeats: Daily'));
      expect(
        preview,
        contains(
          'Check-ins in the last 14 days: ${habits.single['checkInsLast14Days']}',
        ),
      );
      expect(
        preview,
        contains(
          'in a row, since the last change to how often it repeats): ${habits.single['streakPeriods']}',
        ),
      );
      expect(habits.single['checkInsLast14Days'], 3);
      // Recent results.
      final recent = (context['recentTasksLast14Days'] as List)
          .cast<Map<String, Object?>>();
      expect(recent.single['title'], 'Send invoice');
      expect(preview, contains('Recent results (last 14 days)'));
      expect(preview, contains('Title: Send invoice'));
      expect(preview, contains('Result: Finished'));
      expect(preview, contains('Date and time: ${recent.single['at']}'));
      // Goal progress.
      final goals = (context['goalProgressAllTime'] as List)
          .cast<Map<String, Object?>>();
      expect(goals.single, {
        'title': 'Launch',
        'tasksDone': 1,
        'tasksOpen': 1,
        'milestonesDone': 0,
        'milestonesOpen': 0,
      });
      expect(preview, contains('Goal progress (all time)\nTitle: Launch'));
      expect(preview, contains('Linked tasks done: 1'));
      expect(preview, contains('Linked tasks open: 1'));
      expect(preview, contains('Milestones done: 0'));
      expect(preview, contains('Milestones open: 0'));
      // Nothing about a note or an emotion.
      expect(context.containsKey('reportedEmotion'), isFalse);
      expect(context.containsKey('explicitlyAttachedNote'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the review lists them in Spanish too', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, switchOn: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container, language: 'es');
    for (final key in [_habitsChip, _recentChip, _goalChip]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    final preview = await _review(
      tester,
      '¿Cómo van mis hábitos?',
      spanish: true,
    );
    expect(
      preview,
      contains(
        'Fuentes: Tareas, Metas, Hitos, Agenda, Hábitos, Resultados recientes, Progreso de metas',
      ),
    );
    expect(
      preview,
      contains(
        'Hábitos (cumplimientos: últimos 14 días)\nTítulo: Evening walk',
      ),
    );
    expect(preview, contains('Se repite: Diario'));
    expect(preview, contains('Cumplimientos en los últimos 14 días: 3'));
    expect(
      preview,
      contains('seguidos, desde el último cambio de frecuencia): 3'),
    );
    expect(preview, contains('Resultados recientes (últimos 14 días)'));
    expect(preview, contains('Resultado: Terminada'));
    expect(
      preview,
      contains('Progreso de metas (todo el tiempo)\nTítulo: Launch'),
    );
    expect(preview, contains('Tareas vinculadas hechas: 1'));
    expect(preview, contains('Hitos abiertos: 0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Just this chat turns them off and sends none', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, switchOn: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await tester.tap(find.byKey(_habitsChip));
    await tester.pump();
    expect(_on(tester, _habitsChip), isTrue);
    await tester.tap(find.byKey(_chatOnly));
    await tester.pump();
    expect(_on(tester, _habitsChip), isFalse);
    // They add to saved information, so they cannot be turned on without it.
    expect(
      tester.widget<FilterChip>(find.byKey(_habitsChip)).onSelected,
      isNull,
    );
    final preview = await _review(tester, 'How are my habits going?');
    final context = _context(sent.single);
    expect(context['contextScope'], 'chatOnly');
    for (final key in conversationExtraContextKeys) {
      expect(context.containsKey(key), isFalse);
    }
    expect(preview, contains('Sources: just this chat'));
    expect(preview, isNot(contains('Evening walk')));
  });

  testWidgets('every extra field that is sent is a line in the review', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, switchOn: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    for (final key in [_habitsChip, _recentChip, _goalChip]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    final preview = await _review(tester, 'How are my habits going?');
    final context = _context(sent.single);
    final shown = {
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'completed': 'Finished',
      'skipped': 'Skipped',
    };
    final extraKeys = context.keys
        .where(conversationExtraContextKeys.contains)
        .toList();
    expect(extraKeys, hasLength(3));
    for (final key in extraKeys) {
      for (final item in (context[key] as List).cast<Map<String, Object?>>()) {
        for (final entry in item.entries) {
          final value = '${shown[entry.value] ?? entry.value}';
          expect(preview, contains(value), reason: '$key.${entry.key}');
        }
      }
    }
  });

  testWidgets(
    'the heading and the request state the real window for the chosen dates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <Map<String, dynamic>>[];
      final container = _setup(sent, switchOn: true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await tester.tap(find.byKey(_recentChip));
      await tester.tap(find.byKey(_goalChip));
      await tester.pump();
      // The line beside the input names what is on, with its real dates.
      expect(
        find.textContaining(
          'On for every message in this chat until you turn it off: Recent results (last 14 days); Goal progress (all time)',
        ),
        findsOneWidget,
      );

      final advanced = find.byKey(const Key('conversation-advanced'));
      await _reveal(tester, advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      final range = find.byType(DropdownButtonFormField<SIV2TimeRange>);
      await _reveal(tester, range);
      await tester.tap(range);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Recent results (last 7 days); Goal progress'),
        findsOneWidget,
      );
      final preview = await _review(tester, 'Review my week');
      final context = _context(sent.single);
      expect(context['timeRange'], 'sevenDays');
      expect(context.containsKey('recentTasksLast7Days'), isTrue);
      expect(context.containsKey('recentTasksLast14Days'), isFalse);
      expect(preview, contains('Dates: 7 days'));
      expect(preview, contains('Recent results (last 7 days)'));
      expect(preview, contains('Goal progress (all time)'));
      expect(preview, isNot(contains('last 14 days')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an account change turns every extra choice off', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var scope = _scope;
    final container = _setup([], switchOn: true, readScope: () => scope);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await tester.tap(find.byKey(_habitsChip));
    await tester.pump();
    expect(_on(tester, _habitsChip), isTrue);
    expect(find.byKey(const Key('conversation-extra-status')), findsOneWidget);

    scope = AccountStorageScope.authenticated('other-account');
    container.invalidate(accountStorageScopeProvider);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('conversation-extra-status')), findsNothing);
    for (final key in [_habitsChip, _recentChip, _goalChip]) {
      if (find.byKey(key).evaluate().isNotEmpty) {
        expect(_on(tester, key), isFalse);
      }
    }
  });

  group('the full review opens each time the extras are turned on', () {
    /// Sends once. Returns whether the full review opened first; if it did,
    /// it is accepted.
    Future<bool> sendOnce(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'How are my habits going?',
      );
      await tester.tap(find.byKey(const Key('conversation-send')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final shown = find
          .text('Review what AI will receive')
          .evaluate()
          .isNotEmpty;
      if (shown) {
        await tester.tap(find.text('Send'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
      return shown;
    }

    Future<ProviderContainer> start(
      WidgetTester tester,
      List<Map<String, dynamic>> sent, {
      AccountStorageScope Function()? readScope,
    }) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = _setup(sent, switchOn: true, readScope: readScope);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      return container;
    }

    testWidgets('an unchanged selection is not reviewed again, with or '
        'without extras', (tester) async {
      await start(tester, []);
      expect(await sendOnce(tester), isTrue);
      expect(await sendOnce(tester), isFalse);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
      expect(await sendOnce(tester), isFalse);
    });

    testWidgets('after Just this chat', (tester) async {
      await start(tester, []);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
      await tester.tap(find.byKey(_chatOnly));
      await tester.pump();
      await tester.tap(find.byKey(const Key('conversation-scope-my-plan')));
      await tester.pump();
      // The settings are as they were when the review was accepted.
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
    });

    testWidgets('after Clear conversation', (tester) async {
      await start(tester, []);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
      final privacy = find.text('Chat history & privacy');
      await _reveal(tester, privacy);
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      final clear = find.byKey(const Key('conversation-clear-history'));
      await _reveal(tester, clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear conversation').last);
      await tester.pumpAndSettle();
      expect(_on(tester, _habitsChip), isFalse);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
    });

    testWidgets('after reopening the chat in the same app run', (tester) async {
      final container = await start(tester, []);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, container);
      expect(_on(tester, _habitsChip), isFalse);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
    });

    testWidgets('after an account change and back', (tester) async {
      var scope = _scope;
      final container = await start(tester, [], readScope: () => scope);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
      scope = AccountStorageScope.authenticated('other-account');
      container.invalidate(accountStorageScopeProvider);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      scope = _scope;
      container.invalidate(accountStorageScopeProvider);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_on(tester, _habitsChip), isFalse);
      await tester.tap(find.byKey(_habitsChip));
      await tester.pump();
      expect(await sendOnce(tester), isTrue);
    });
  });

  for (final language in ['en', 'es']) {
    for (final scale in [1.5, 2.0]) {
      testWidgets(
        '$language all three choices on fit 320 px at text scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final container = _setup([], switchOn: true);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
          });
          await _pump(tester, container, language: language, textScale: scale);
          expect(tester.takeException(), isNull, reason: 'before choosing');
          for (final key in [_habitsChip, _recentChip, _goalChip]) {
            await _reveal(tester, find.byKey(key));
            await tester.tap(find.byKey(key));
            await tester.pump();
            expect(_on(tester, key), isTrue);
            expect(
              tester.getSize(find.byKey(key)).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(
            find.byKey(const Key('conversation-extra-status')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language extra choices fit 320 px at 200 percent text and are 48 high',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        final container = _setup([], switchOn: true);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language, textScale: 2);
        final spanish = language == 'es';
        for (final entry in {
          _habitsChip: spanish ? 'Hábitos' : 'Habits',
          _recentChip: spanish ? 'Resultados recientes' : 'Recent results',
          _goalChip: spanish ? 'Progreso de metas' : 'Goal progress',
        }.entries) {
          await tester.ensureVisible(find.byKey(entry.key));
          expect(
            find.descendant(
              of: find.byKey(entry.key),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byKey(entry.key)).height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(
          find.bySemanticsLabel(
            RegExp(
              spanish
                  ? r'^Más información que puede usar el chat con IA, desactivada salvo que la actives'
                  : r'^More information AI chat can use, off unless you turn it on',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(_habitsChip));
        await tester.pump();
        expect(_on(tester, _habitsChip), isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

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
  @override
  Future<List<TaskEntity>> getAllTasks() async => _tasks;
  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      _tasks.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> saveTask(TaskEntity task) =>
      throw StateError('Conversation must not mutate tasks');
  @override
  Future<void> deleteTask(String id) =>
      throw StateError('Conversation must not mutate tasks');
}
