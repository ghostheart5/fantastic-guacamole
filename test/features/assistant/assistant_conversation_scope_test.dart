import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
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

// Chat uses the person's plan by default, shows that above the input, and
// lets them send nothing from it. What a request carries is what the review
// shows.

final _scope = AccountStorageScope.authenticated('synthetic-scope');
final _records = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    description: 'Milk, rice and vegetables for dinner.',
    estimatedDuration: const Duration(minutes: 45),
  ),
];
SIV2ReadGateway _gatewayFor(String? scope) => SIV2ReadGateway(
  accountScopeId: scope!,
  readTasks: () async => _records,
  readGoals: () async => [],
  readMilestones: () async => [],
  readTimeline: () async => [],
);

const _myPlan = Key('conversation-scope-my-plan');
const _chatOnly = Key('conversation-scope-chat-only');
const _notice = Key('conversation-scope-notice');
const _noticeText =
    'AI chat now uses your plan (tasks, goals, milestones and schedule) so replies fit your day. See what is sent shows what goes, and it opens by itself before your first message each time the app opens and whenever this choice changes. Choose Just this chat to send none of it.';

ProviderContainer _setup(
  List<Map<String, dynamic>> sent,
  InMemorySecureStoreBackend backend, {
  AccountStorageScope Function()? readScope,
}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
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
      ).read(observedAt: DateTime.now()),
    ),
    domainTaskRepositoryProvider.overrideWithValue(_Tasks()),
    selectedPlanningNoteProvider.overrideWith(
      (ref) async => NoteEntity(
        id: 'list-note',
        title: 'Dinner shopping',
        body: 'Check the pantry before buying rice.',
        createdAt: DateTime(2026, 9, 16),
        taskId: 'grocery',
      ),
    ),
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

Future<void> _waitForReady(WidgetTester tester) async {
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 60; i++) {
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(tester.widget<TextField>(input).enabled, isTrue);
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
  await _waitForReady(tester);
  await tester.pump();
}

bool _selected(WidgetTester tester, Key key) =>
    tester.widget<ChoiceChip>(find.byKey(key)).selected;

/// Sends [prompt] up to the price step and returns the review's text about
/// the information included. Asking for the price sends the packet once.
Future<String> _reviewAndAskPrice(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byKey(const Key('conversation-input')), prompt);
  await tester.tap(find.byKey(const Key('conversation-send')));
  // The first message opens the full preview by itself, records visible
  // without another tap.
  await _waitFor(tester, find.text('Review what AI will receive'));
  final preview = tester
      .widgetList<SelectableText>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SelectableText),
        ),
      )
      .map((widget) => widget.data ?? widget.textSpan!.toPlainText())
      .join('\n');
  await tester.tap(find.text('Send'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return preview;
}

Map<String, dynamic> _context(Map<String, dynamic> body) =>
    Map<String, dynamic>.from(body['context'] as Map);

void main() {
  testWidgets(
    'a new chat uses My plan, shown above the input, and the review lists exactly what is sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <Map<String, dynamic>>[];
      final container = _setup(sent, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);

      // Visible without opening anything.
      expect(find.byKey(_myPlan).hitTestable(), findsOneWidget);
      expect(find.byKey(_chatOnly).hitTestable(), findsOneWidget);
      expect(_selected(tester, _myPlan), isTrue);
      expect(_selected(tester, _chatOnly), isFalse);
      expect(find.text(_noticeText), findsOneWidget);

      final preview = await _reviewAndAskPrice(
        tester,
        'When should I do the Grocery list?',
      );
      expect(sent, hasLength(1));
      final context = _context(sent.single);
      expect(context['selectedSources'], [
        'goals',
        'milestones',
        'tasks',
        'timeline',
      ]);
      expect(context.containsKey('contextScope'), isFalse);
      expect(preview, contains('Sources: Tasks, Goals, Milestones, Schedule'));
      final titles = [
        for (final source in SIV2Source.values)
          for (final record in context[source.name] as List)
            (record as Map)['title'] as String,
      ];
      expect(titles, contains('Grocery list'));
      for (final title in titles) {
        expect(preview, contains(title));
      }
      // The note is not part of Chat's plan; it is neither sent nor shown.
      expect(context.containsKey('explicitlyAttachedNote'), isFalse);
      expect(preview, isNot(contains('Dinner shopping')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Just this chat sends nothing from the plan and is kept', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final backend = InMemorySecureStoreBackend();
    final first = _setup(sent, backend);
    await _pump(tester, first);
    await tester.tap(find.byKey(_chatOnly));
    await tester.pump();
    expect(_selected(tester, _chatOnly), isTrue);
    expect(_selected(tester, _myPlan), isFalse);

    final preview = await _reviewAndAskPrice(
      tester,
      'When should I do the Grocery list?',
    );
    final context = _context(sent.single);
    expect(context['selectedSources'], isEmpty);
    expect(context['contextScope'], 'chatOnly');
    for (final source in SIV2Source.values) {
      expect(context[source.name], isEmpty);
    }
    expect(preview, contains('Sources: just this chat'));
    expect(preview, isNot(contains('Milk, rice')));

    // The choice is the person's own: it is restored after a restart.
    final saved = await first
        .read(assistantConversationHistoryRepositoryProvider)!
        .load();
    expect(saved.sourcesChosen, isTrue);
    expect(saved.sources, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    final restarted = _setup(sent, backend);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      restarted.dispose();
    });
    await _pump(tester, restarted);
    expect(_selected(tester, _chatOnly), isTrue);
    expect(_selected(tester, _myPlan), isFalse);
    expect(find.byKey(_notice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved partial choice is restored and shown as chosen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, InMemorySecureStoreBackend());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await container
        .read(assistantConversationHistoryRepositoryProvider)!
        .save(
          expectedRevision: 0,
          messages: const [],
          sources: {SIV2Source.goals},
        );
    await _pump(tester, container);
    expect(_selected(tester, _myPlan), isFalse);
    expect(_selected(tester, _chatOnly), isFalse);
    // Shown as a plain label: a screen reader is not offered a control that
    // does nothing.
    final custom = find.byKey(const Key('conversation-scope-custom'));
    expect(tester.widget(custom), isA<Chip>());
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(tester.getSemantics(custom), isNot(isSemantics(hasTapAction: true)));
    semantics.dispose();
    expect(find.text('Goals only'), findsOneWidget);
    // Someone who already chose is not told about the default.
    expect(find.byKey(_notice), findsNothing);
    await _reviewAndAskPrice(tester, 'When should I do the Grocery list?');
    expect(_context(sent.single)['selectedSources'], ['goals']);
  });

  testWidgets(
    'the explanation shows once per account and the choice never crosses accounts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var current = _scope;
      final sent = <Map<String, dynamic>>[];
      final container = _setup(
        sent,
        InMemorySecureStoreBackend(),
        readScope: () => current,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      expect(find.text(_noticeText), findsOneWidget);
      await tester.tap(find.byKey(_chatOnly));
      await tester.pump();

      current = AccountStorageScope.authenticated('synthetic-other');
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _waitForReady(tester);
      await tester.pump();
      expect(_selected(tester, _myPlan), isTrue);
      expect(_selected(tester, _chatOnly), isFalse);
      expect(find.text(_noticeText), findsOneWidget);
      final other = await container
          .read(assistantConversationHistoryRepositoryProvider)!
          .load();
      expect(other.sourcesChosen, isFalse);

      current = _scope;
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _waitForReady(tester);
      await tester.pump();
      expect(_selected(tester, _chatOnly), isTrue);
      expect(find.byKey(_notice), findsNothing);
      final own = await container
          .read(assistantConversationHistoryRepositoryProvider)!
          .load();
      expect(own.scopeExplained, isTrue);
      expect(sent, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clearing the conversation goes back to My plan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <Map<String, dynamic>>[];
    final container = _setup(sent, InMemorySecureStoreBackend());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await container
        .read(assistantConversationHistoryRepositoryProvider)!
        .save(
          expectedRevision: 0,
          messages: const [
            {'role': 'user', 'content': 'A quiet break after work'},
            {'role': 'assistant', 'content': 'Try a short pause.'},
          ],
          sources: {},
        );
    await _pump(tester, container);
    expect(_selected(tester, _chatOnly), isTrue);
    Future<void> tapInList(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapInList(find.text('Chat history & privacy'));
    await tapInList(find.byKey(const Key('conversation-clear-history')));
    await tester.tap(find.text('Clear conversation').last);
    await tester.pumpAndSettle();
    expect(_selected(tester, _myPlan), isTrue);
    expect(
      (await container
              .read(assistantConversationHistoryRepositoryProvider)!
              .load())
          .sourcesChosen,
      isFalse,
    );
  });

  testWidgets(
    'a chat saved by the previous version with nothing selected stays Just this chat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      // Exactly what the previous version stored: no choice marker.
      await SecureStore(backend: backend)
          .forAccount(_scope)
          .writeString(
            AssistantConversationRepository.storageKey,
            jsonEncode({
              'version': 1,
              'revision': 2,
              'messages': [
                {'role': 'user', 'content': 'A quiet break after work'},
                {'role': 'assistant', 'content': 'Try a short pause.'},
              ],
              'sources': <String>[],
            }),
          );
      final sent = <Map<String, dynamic>>[];
      final container = _setup(sent, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      expect(_selected(tester, _chatOnly), isTrue);
      expect(_selected(tester, _myPlan), isFalse);
      final preview = await _reviewAndAskPrice(
        tester,
        'When should I do the Grocery list?',
      );
      final context = _context(sent.single);
      expect(context['selectedSources'], isEmpty);
      expect(context['contextScope'], 'chatOnly');
      for (final source in SIV2Source.values) {
        expect(context[source.name], isEmpty);
      }
      expect(preview, contains('Sources: just this chat'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'after switching to an account whose chat cannot load, clearing it shows the line',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final other = AccountStorageScope.authenticated('synthetic-damaged');
      await SecureStore(backend: backend)
          .forAccount(other)
          .writeString(
            AssistantConversationRepository.storageKey,
            jsonEncode({
              'version': 1,
              'revision': 1,
              'messages': <Object?>[],
              'sources': ['unknown'],
            }),
          );
      var current = _scope;
      final container = _setup([], backend, readScope: () => current);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      // This account sees and records the line.
      expect(find.text(_noticeText), findsOneWidget);
      await tester.pump();

      current = other;
      container.invalidate(accountStorageScopeProvider);
      await tester.pumpAndSettle();
      expect(find.text('Retry loading chat'), findsOneWidget);
      // A chat that did not load claims no saved choice.
      expect(
        find.text('Planning sources: shown once the saved chat loads.'),
        findsOneWidget,
      );
      expect(find.text('Saved planning sources: off.'), findsNothing);
      final privacy = find.text('Chat history & privacy');
      await tester.scrollUntilVisible(
        privacy,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      final clear = find.byKey(const Key('conversation-clear-history'));
      await tester.scrollUntilVisible(
        clear,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear conversation').last);
      await tester.pumpAndSettle();
      expect(_selected(tester, _myPlan), isTrue);
      await tester.scrollUntilVisible(
        find.byKey(_notice),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_noticeText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language scope row and explanation fit 320 px at 200 percent text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        final container = _setup([], InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language, textScale: 2);
        final spanish = language == 'es';
        expect(
          find.descendant(
            of: find.byKey(_myPlan),
            matching: find.text(spanish ? 'Mi plan' : 'My plan'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_chatOnly),
            matching: find.text(
              spanish ? 'Solo esta conversación' : 'Just this chat',
            ),
          ),
          findsOneWidget,
        );
        final notice = find.byKey(_notice);
        await tester.scrollUntilVisible(
          notice,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            spanish
                ? 'El chat con IA ahora usa tu plan (tareas, metas, hitos y agenda) para que las respuestas se ajusten a tu día. Ver qué se envía muestra lo que se envía, y se abre solo antes de tu primer mensaje cada vez que abres la app y cada vez que cambia esta elección. Elige Solo esta conversación para no enviar nada de tu plan.'
                : _noticeText,
          ),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(_chatOnly)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          find.bySemanticsLabel(
            spanish
                ? 'Información que usa el chat con IA'
                : 'Information AI chat uses',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(_chatOnly));
        await tester.pump();
        expect(_selected(tester, _chatOnly), isTrue);
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
  Future<List<TaskEntity>> getAllTasks() async => _records;
  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      _records.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> saveTask(TaskEntity task) =>
      throw StateError('Conversation must not mutate tasks');
  @override
  Future<void> deleteTask(String id) =>
      throw StateError('Conversation must not mutate tasks');
}
