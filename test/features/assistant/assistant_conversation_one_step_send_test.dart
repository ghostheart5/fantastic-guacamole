import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
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

// Sending a paid AI chat message takes one tap: the send button states the
// price and tapping it confirms that price. The full preview opens by itself
// the first time and when the selection changes; a different signed price is
// asked about before anything is charged.

typedef _Response = ({int status, Map<String, dynamic> data});

final _scope = AccountStorageScope.authenticated('synthetic-one-step');
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

const _send = Key('conversation-send');
const _preview = Key('conversation-preview');
const _suggestion = Key('conversation-free-suggestion');

class _Server {
  _Server({this.credits = conversationMessageCredits, this.quoteError});
  final int credits;
  final String? quoteError;
  int quotes = 0;
  final paid = <Map<String, dynamic>>[];

  Future<_Response> call(Map<String, dynamic> body) async {
    if (body['quoteOnly'] == true) {
      quotes++;
      if (quoteError case final String error) {
        return (status: 429, data: <String, dynamic>{'error': error});
      }
      return (
        status: 200,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'quote': <String, dynamic>{
            'credits': credits,
            'digest': 'fixture',
            'proof': 'fixture',
            'policy': 'fixture',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          },
        },
      );
    }
    paid.add(body);
    return (
      status: 200,
      data: <String, dynamic>{
        'requestId': body['requestId'],
        'message': 'Reply ${paid.length}.',
        'creditsCharged': credits,
        'remainingCredits': 20,
        'model': 'transport-fixture',
      },
    );
  }
}

NoteEntity _note = _dinnerNote;
final _dinnerNote = NoteEntity(
  id: 'list-note',
  title: 'Dinner shopping',
  body: 'Check the pantry before buying rice.',
  createdAt: DateTime(2026, 9, 16),
  taskId: 'grocery',
);

ProviderContainer _setup(
  _Server server,
  InMemorySecureStoreBackend backend, {
  AccountStorageScope Function()? readScope,
  ConversationTransport? transport,
}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(transport ?? server.call),
    consentedHumanContextProvider.overrideWith((ref) => _human),
    siV2ReadGatewayProvider.overrideWith(
      (ref) => _gatewayFor(ref.watch(accountStorageScopeProvider).v2Namespace),
    ),
    siV2PersonContextRevisionProvider.overrideWithValue('fixture'),
    siV2EvidenceSnapshotProvider.overrideWith(
      (ref) => _gatewayFor(
        ref.watch(accountStorageScopeProvider).v2Namespace,
      ).read(observedAt: DateTime.now()),
    ),
    domainTaskRepositoryProvider.overrideWithValue(_Tasks()),
    selectedPlanningNoteProvider.overrideWith((ref) async => _note),
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

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  ConversationSurface surface = ConversationSurface.si,
  ValueChanged<String>? onDraft,
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
          surface: surface,
          onLocalTools: () {},
          onLocalToolsWithDraft: onDraft,
        ),
      ),
    ),
  );
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      break;
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapSend(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byKey(const Key('conversation-input')), prompt);
  await tester.pump();
  await tester.ensureVisible(find.byKey(_send));
  await tester.tap(find.byKey(_send));
  await _settle(tester);
}

Finder get _previewDialog => find.text('Review what AI will receive');

Future<void> _acceptPreview(WidgetTester tester) async {
  expect(_previewDialog, findsOneWidget);
  await tester.tap(find.text('Send'));
  await _settle(tester);
}

String _dialogText(WidgetTester tester) => tester
    .widgetList<SelectableText>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SelectableText),
      ),
    )
    .map((widget) => widget.data ?? '')
    .join('\n');

void main() {
  for (final language in ['en', 'es']) {
    testWidgets('$language: the send button states the price', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = _setup(_Server(), InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container, language: language);
      expect(
        find.descendant(
          of: find.byKey(_send),
          matching: find.text(
            language == 'es' ? 'Enviar · 5 créditos' : 'Send · 5 credits',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_preview),
          matching: find.text(
            language == 'es' ? 'Ver qué se envía' : 'See what is sent',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a matching quote sends with one tap and exactly one reservation; the preview shows only the first time',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final server = _Server();
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);

      // First message: the full preview opens by itself, with the plan
      // records visible without another tap. Nothing is sent before it.
      await _tapSend(tester, 'When should I do the Grocery list?');
      expect(_previewDialog, findsOneWidget);
      expect(server.quotes, 0);
      expect(_dialogText(tester), contains('Grocery list'));
      expect(_dialogText(tester), contains('Milk, rice'));
      await _acceptPreview(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.quotes, 1);
      expect(server.paid, hasLength(1));
      expect(find.text('Reply 1.'), findsOneWidget);

      // Same selection: one tap, no dialog of any kind.
      await _tapSend(tester, 'And after that?');
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.quotes, 2);
      expect(server.paid, hasLength(2));
      expect(find.text('Reply 2.'), findsOneWidget);
      expect(
        server.paid.map((body) => body['requestId']).toSet(),
        hasLength(2),
        reason: 'One reservation per message',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Choose a step also sends with one tap after its first preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final server = _Server();
    final container = _setup(server, InMemorySecureStoreBackend());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container, surface: ConversationSurface.planner);
    await _tapSend(tester, 'Compare my two options.');
    await _acceptPreview(tester);
    expect(server.paid, hasLength(1));
    await _tapSend(tester, 'And the second?');
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.paid, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: a different signed price is asked about before anything is charged',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(credits: 7);
        final backend = InMemorySecureStoreBackend();
        final container = _setup(server, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await _tapSend(tester, 'Compare my two options.');
        await tester.tap(find.text(language == 'es' ? 'Enviar' : 'Send'));
        await _settle(tester);
        expect(server.quotes, 1);
        expect(
          find.text(
            language == 'es'
                ? 'El precio es distinto'
                : 'The price is different',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'es'
                ? 'cuesta 7 créditos, no los 5'
                : 'costs 7 credits, not the 5',
          ),
          findsOneWidget,
        );
        // Declining: nothing stored, sent for a reply or charged.
        await tester.tap(find.text(language == 'es' ? 'Cancelar' : 'Cancel'));
        await _settle(tester);
        expect(server.paid, isEmpty);
        final stored = await SecureStore(backend: backend)
            .forAccount(_scope)
            .readString(AssistantConversationRepository.storageKey);
        expect(stored ?? '', isNot(contains('pendingRequests')));

        // Accepting the new price sends it once.
        await tester.tap(find.byKey(_send));
        await _settle(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(
          find.text(language == 'es' ? 'Usar 7 créditos' : 'Use 7 credits'),
        );
        await _settle(tester);
        expect(server.paid, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'the preview opens again after the selection changes and is always one tap away',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final server = _Server();
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _tapSend(tester, 'When should I do the Grocery list?');
      await _acceptPreview(tester);
      expect(server.paid, hasLength(1));

      await tester.ensureVisible(
        find.byKey(const Key('conversation-scope-chat-only')),
      );
      await tester.tap(find.byKey(const Key('conversation-scope-chat-only')));
      await tester.pump();
      await _tapSend(tester, 'Anything else?');
      expect(_previewDialog, findsOneWidget);
      expect(server.quotes, 1, reason: 'Nothing is sent before the preview');
      expect(_dialogText(tester), contains('Sources: just this chat'));
      await _acceptPreview(tester);
      expect(server.paid, hasLength(2));

      // Same selection again: no automatic preview, but See what is sent
      // opens it, and cancelling sends nothing.
      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'One more?',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(_preview));
      await tester.tap(find.byKey(_preview));
      await _settle(tester);
      expect(_previewDialog, findsOneWidget);
      expect(_dialogText(tester), contains('One more?'));
      expect(_dialogText(tester), contains('Anything else?'));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(server.quotes, 2);
      expect(server.paid, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: the free on-device suggestion never blocks sending',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server();
        final handed = <String>[];
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language, onDraft: handed.add);
        final draft = language == 'es'
            ? '¿Qué tarea está vencida?'
            : 'Which task is overdue?';
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          draft,
        );
        await _settle(tester);
        expect(
          find.descendant(
            of: find.byKey(_suggestion),
            matching: find.text(
              language == 'es'
                  ? 'Responder gratis en este dispositivo'
                  : 'Answer free on this device',
            ),
          ),
          findsOneWidget,
        );
        // Ignoring it: send goes straight on, no dialog about free tools.
        await tester.tap(find.byKey(_send));
        await _settle(tester);
        expect(
          find.text(
            language == 'es'
                ? 'Revisa lo que recibirá la IA'
                : 'Review what AI will receive',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(language == 'es' ? 'Enviar' : 'Send'));
        await _settle(tester);
        expect(server.paid, hasLength(1));
        expect(handed, isEmpty);
        // The draft was cleared after the reply, so the suggestion is gone.
        expect(find.byKey(_suggestion), findsNothing);

        // Taking it carries the draft to the free tools; nothing is sent.
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          draft,
        );
        await _settle(tester);
        await tester.tap(find.byKey(_suggestion));
        await _settle(tester);
        expect(handed, [draft]);
        expect(server.quotes, 1);
        expect(server.paid, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: at 320x640 and 200 percent text, send, preview and an error stay reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(quoteError: 'rate_limit_exceeded');
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language, textScale: 2);
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'Compare my two options.',
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(_send).hitTestable(), findsOneWidget);
        expect(find.byKey(_preview).hitTestable(), findsOneWidget);
        expect(tester.getSize(find.byKey(_send)).height, greaterThan(47));
        expect(tester.getSize(find.byKey(_preview)).height, greaterThan(47));

        await tester.tap(find.byKey(_send));
        await _settle(tester);
        final accept = find.text(language == 'es' ? 'Enviar' : 'Send');
        await tester.ensureVisible(accept);
        await tester.pump();
        await tester.tap(accept);
        await _settle(tester);
        expect(server.quotes, 1);
        final error = find.byKey(const Key('conversation-error'));
        expect(error, findsOneWidget);
        // The list scrolls to the error; its end is on screen above the
        // controls (the message is taller than the space at this size).
        expect(error.hitTestable(at: const Alignment(0, 0.8)), findsOneWidget);
        expect(find.byKey(_send).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the preview opens again after an account change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var current = _scope;
    final server = _Server();
    final container = _setup(
      server,
      InMemorySecureStoreBackend(),
      readScope: () => current,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await _tapSend(tester, 'First question.');
    await _acceptPreview(tester);
    await _tapSend(tester, 'Second question.');
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.paid, hasLength(2));

    Future<void> switchTo(AccountStorageScope scope) async {
      current = scope;
      container.invalidate(accountStorageScopeProvider);
      await _settle(tester);
    }

    await switchTo(AccountStorageScope.authenticated('synthetic-other'));
    await switchTo(_scope);
    await _tapSend(tester, 'Third question.');
    expect(_previewDialog, findsOneWidget);
    expect(server.quotes, 2, reason: 'Nothing is sent before the preview');
    await _acceptPreview(tester);
    expect(server.paid, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Choose a step names what it uses above the input and a changed note reopens the preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() {
        _note = _dinnerNote;
        return tester.binding.setSurfaceSize(null);
      });
      final server = _Server();
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container, surface: ConversationSurface.planner);
      final line = find.byKey(const Key('conversation-planner-scope'));
      expect(
        tester.widget<Text>(line).data,
        'AI chat uses: tasks, goals, milestones and schedule picked for your question; your note “Dinner shopping”.',
      );
      await _tapSend(tester, 'Compare my two options.');
      expect(_dialogText(tester), contains('Dinner shopping'));
      await _acceptPreview(tester);
      await _tapSend(tester, 'And the second?');
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.paid, hasLength(2));

      // A different note, chosen on another screen, is new information.
      _note = NoteEntity(
        id: 'list-note',
        title: 'Weekend errands',
        body: 'Post office before noon.',
        createdAt: DateTime(2026, 9, 17),
        taskId: 'grocery',
      );
      container.invalidate(selectedPlanningNoteProvider);
      await _settle(tester);
      expect(
        tester.widget<Text>(line).data,
        contains('your note “Weekend errands”'),
      );
      await _tapSend(tester, 'And now?');
      expect(_previewDialog, findsOneWidget);
      expect(_dialogText(tester), contains('Post office before noon.'));
      expect(server.quotes, 2);
      await _acceptPreview(tester);
      expect(server.paid, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the preview lists the technical details sent with records', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _setup(_Server(), InMemorySecureStoreBackend());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await _tapSend(tester, 'When should I do the Grocery list?');
    expect(find.text('Also sent'), findsOneWidget);
    expect(
      _dialogText(tester),
      contains('your local date and time, time zone and language'),
    );
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
  });
  testWidgets(
    'the preview opens again after a session change for the same account',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => _sessionGeneration = 1);
      final server = _Server();
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _tapSend(tester, 'First question.');
      await _acceptPreview(tester);
      _sessionGeneration = 2;
      container.invalidate(authSessionBoundaryProvider);
      await _settle(tester);
      await _tapSend(tester, 'Second question.');
      expect(_previewDialog, findsOneWidget);
      expect(server.quotes, 1, reason: 'Nothing is sent before the preview');
      await _acceptPreview(tester);
      expect(server.paid, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: Choose a step names the emotional state in words, and a changed energy or emotion reopens the preview',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 1400));
        addTearDown(() {
          _human = _noEmotion;
          return tester.binding.setSurfaceSize(null);
        });
        _human = const ConsentedHumanContext(
          emotionAllowed: true,
          memoryAllowed: false,
          emotion: EmotionalState.fatigued,
          siState: SIState(),
        );
        final server = _Server();
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(
          tester,
          container,
          language: language,
          surface: ConversationSurface.planner,
        );
        final spanish = language == 'es';
        final line = find.byKey(const Key('conversation-planner-scope'));
        expect(
          tester.widget<Text>(line).data,
          contains(
            spanish
                ? 'tu estado emocional (con cansancio)'
                : 'your emotional state (fatigued)',
          ),
        );
        final send = spanish ? 'Enviar' : 'Send';
        final review = spanish
            ? 'Revisa lo que recibirá la IA'
            : 'Review what AI will receive';
        Future<void> sendMessage(String text) async {
          await tester.enterText(
            find.byKey(const Key('conversation-input')),
            text,
          );
          await tester.pump();
          await tester.ensureVisible(find.byKey(_send));
          await tester.tap(find.byKey(_send));
          await _settle(tester);
        }

        await sendMessage('One?');
        expect(find.text(review), findsOneWidget);
        await tester.tap(find.text(send));
        await _settle(tester);
        await sendMessage('Two?');
        expect(find.byType(AlertDialog), findsNothing);
        expect(server.paid, hasLength(2));

        // A different emotional state is new information.
        _human = const ConsentedHumanContext(
          emotionAllowed: true,
          memoryAllowed: false,
          emotion: EmotionalState.calm,
          siState: SIState(),
        );
        container.invalidate(consentedHumanContextProvider);
        await _settle(tester);
        await sendMessage('Three?');
        expect(find.text(review), findsOneWidget);
        expect(server.quotes, 2);
        await tester.tap(find.text(send));
        await _settle(tester);
        expect(server.paid, hasLength(3));

        // So is a different energy value.
        final energyTile = find.text(
          spanish
              ? '¿Cuánta energía tienes? (opcional)'
              : 'How much energy do you have? (optional)',
        );
        // The options sit at the top of the scrolled conversation.
        await tester.scrollUntilVisible(
          energyTile,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(energyTile);
        await _settle(tester);
        final energy = find.byType(DropdownButtonFormField<double>);
        await tester.ensureVisible(energy);
        await tester.tap(energy);
        await _settle(tester);
        await tester.tap(find.text('40%').last);
        await _settle(tester);
        expect(
          tester.widget<Text>(line).data,
          contains(spanish ? 'tu energía (40%)' : 'your energy (40%)'),
        );
        await sendMessage('Four?');
        expect(find.text(review), findsOneWidget);
        expect(server.quotes, 3);
        await tester.tap(find.text(send));
        await _settle(tester);
        expect(server.paid, hasLength(4));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sentForReply in [false, true]) {
    testWidgets(
      'an unexpected failure ${sentForReply ? 'after the request was handed on keeps it for Retry' : 'before anything was handed on says nothing was charged'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var executes = 0;
        final container = _setup(
          _Server(),
          InMemorySecureStoreBackend(),
          transport: (body) async {
            if (body['quoteOnly'] == true) {
              if (!sentForReply) throw StateError('synthetic_network_failure');
              return _Server().call(body);
            }
            executes++;
            throw StateError('synthetic_network_failure');
          },
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container);
        await _tapSend(tester, 'Compare my two options.');
        await _acceptPreview(tester);
        final error = find.byKey(const Key('conversation-error'));
        expect(error, findsOneWidget);
        if (sentForReply) {
          expect(executes, 1);
          expect(
            find.textContaining('did not confirm a reply'),
            findsOneWidget,
          );
          expect(find.textContaining('Nothing was charged'), findsNothing);
          expect(find.text('Retry same request'), findsOneWidget);
        } else {
          expect(executes, 0);
          expect(
            // Only this branch says it: other failures share parts of it.
            find.text(
              'The AI service could not be reached. Nothing was sent for a reply and nothing was charged. Your question is retained; tap send to try again.',
            ),
            findsOneWidget,
          );
          expect(find.text('Retry same request'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _noEmotion = ConsentedHumanContext(
  emotionAllowed: false,
  memoryAllowed: false,
  emotion: null,
  siState: SIState(),
);
ConsentedHumanContext _human = _noEmotion;

/// A session-boundary change for the same account raises this.
var _sessionGeneration = 1;

class _Consent extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() =>
      const PersonalizationProfile(externalAiAllowed: true);
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => AuthSessionBoundary(
    generation: _sessionGeneration,
    userId: 'synthetic-one-step',
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
