import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Response = ({int status, Map<String, dynamic> data});

final _scope = AccountStorageScope.authenticated('synthetic-pending');
final _records = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    description: 'Milk, rice and vegetables for dinner.',
    estimatedDuration: const Duration(minutes: 45),
  ),
];
final _gateway = SIV2ReadGateway(
  accountScopeId: _scope.v2Namespace!,
  readTasks: () async => _records,
  readGoals: () async => [],
  readMilestones: () async => [],
  readTimeline: () async => [],
);

ProviderContainer _setup(
  ConversationTransport transport,
  InMemorySecureStoreBackend backend, {
  Duration? paidWaitTimeout,
  AccountStorageScope Function()? readScope,
  Completer<void>? releaseGate,
  bool fakeClockPurgeTimer = false,
  DateTime Function()? clock,
}) => ProviderContainer(
  overrides: [
    if (clock != null) conversationClockProvider.overrideWithValue(clock),
    if (fakeClockPurgeTimer)
      conversationPurgeTimerProvider.overrideWithValue(Timer.new),
    secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(transport),
    if (paidWaitTimeout != null)
      conversationPaidWaitTimeoutProvider.overrideWithValue(paidWaitTimeout),
    siV2ReadGatewayProvider.overrideWithValue(_gateway),
    siV2PersonContextRevisionProvider.overrideWithValue('fixture-revision'),
    siV2EvidenceSnapshotProvider.overrideWith(
      (ref) => _gateway.read(observedAt: DateTime.now()),
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
      assistantReleaseDecisionProvider(capability).overrideWith((ref) async {
        if (releaseGate != null) await releaseGate.future;
        return AssistantReleaseDecision(
          enabled: true,
          shadowEvaluationEnabled: false,
          cohort: AssistantReleaseCohort.internal,
          reasonCode: 'synthetic-test',
          accountDigest: 'test',
          capability: capability,
          configDigest: 'test',
        );
      }),
  ],
);

_Response _quote(
  Map<String, dynamic> body, {
  Duration valid = const Duration(minutes: 5),
  int credits = 4,
}) => (
  status: 200,
  data: <String, dynamic>{
    'requestId': body['requestId'],
    'quote': <String, dynamic>{
      'credits': credits,
      'digest': 'fixture',
      'proof': 'fixture',
      'policy': 'fixture',
      'expiresAt': DateTime.now().add(valid).millisecondsSinceEpoch,
    },
  },
);

_Response _answer(Object? requestId, String text, {int credits = 4}) => (
  status: 200,
  data: <String, dynamic>{
    'requestId': requestId,
    'message': text,
    'creditsCharged': credits,
    'remainingCredits': 20,
    'model': 'transport-fixture',
  },
);

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  ConversationSurface surface, {
  String language = 'en',
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
        home: AssistantConversationScreen(
          surface: surface,
          onLocalTools: () {},
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Leaving replaces the conversation with another screen, as the navigation
/// shell does for Settings, the creator or any non-tab view.
Future<void> _leave(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: Text('Settings'))),
    ),
  );
  await tester.pump();
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> _confirmPaidRequest(WidgetTester tester, String prompt) async {
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 40; i++) {
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.enterText(input, prompt);
  // Tapping send confirms the price on the button; the first message shows
  // the full preview, and the fixture's price (4) differs from the button's
  // (5), so it is confirmed too.
  await tester.tap(find.byKey(const Key('conversation-send')));
  await _waitFor(tester, find.text('Send'));
  await tester.tap(find.text('Send'));
  await _waitFor(tester, find.text('Use 4 credits'));
  await tester.tap(find.text('Use 4 credits'));
  // Let the confirmation dialog finish closing before anything else.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<String?> _storedChat(InMemorySecureStoreBackend backend) => SecureStore(
  backend: backend,
).forAccount(_scope).readString(AssistantConversationRepository.storageKey);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name}: a confirmed paid request survives leaving the screen and its reply appears once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        final reply = Completer<_Response>();
        final paid = <Map<String, dynamic>>[];
        var quotes = 0;
        final container = _setup((body) async {
          if (body['quoteOnly'] == true) {
            quotes++;
            return _quote(body);
          }
          paid.add(body);
          return reply.future;
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });

        await _pumpScreen(tester, container, surface);
        await _confirmPaidRequest(tester, 'Compare my two options.');
        expect(find.text('Preparing your response…'), findsOneWidget);
        expect(paid, hasLength(1));

        await _leave(tester, container);
        expect(find.text('Settings'), findsOneWidget);
        await _pumpScreen(tester, container, surface);

        reply.complete(
          _answer(paid.single['requestId'], 'The recovered paid reply.'),
        );
        await _settle(tester);

        expect(find.text('The recovered paid reply.'), findsOneWidget);
        expect(paid, hasLength(1), reason: 'Exactly one reservation request');
        expect(quotes, 1);
        expect(find.text('Retry same request'), findsNothing);
        final stored = await _storedChat(backend);
        expect(stored, isNot(contains('pendingRequests')));
        if (surface == ConversationSurface.si) {
          expect(stored, contains('The recovered paid reply.'));
        }

        // Returning again must not show or request the same reply again.
        await _leave(tester, container);
        await _pumpScreen(tester, container, surface);
        await _settle(tester);
        final recovered = find.text('The recovered paid reply.');
        if (surface == ConversationSurface.si) {
          // Saved Chat reopens at the top; the reply is further down.
          await tester.scrollUntilVisible(
            recovered,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(recovered, findsOneWidget);
        } else {
          expect(recovered, findsNothing);
        }
        expect(paid, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'after an app restart the same signed request is re-sent byte for byte and its cached reply shown once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final never = Completer<_Response>();
      final firstPaid = <Map<String, dynamic>>[];
      final first = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        firstPaid.add(body);
        return never.future;
      }, backend);
      await _pumpScreen(tester, first, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      expect(firstPaid, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();

      final secondPaid = <Map<String, dynamic>>[];
      var secondQuotes = 0;
      final second = _setup((body) async {
        if (body['quoteOnly'] == true) {
          secondQuotes++;
          return _quote(body);
        }
        secondPaid.add(body);
        return _answer(body['requestId'], 'The cached paid reply.');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);

      expect(secondQuotes, 0);
      expect(secondPaid, hasLength(1));
      expect(jsonEncode(secondPaid.single), jsonEncode(firstPaid.single));
      expect(find.text('The cached paid reply.'), findsOneWidget);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a request persisted by the previous version (no sourcesChosen marker) is re-sent byte for byte',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final quote = ConversationQuote(
        packet: ConversationPacket(
          surface: ConversationSurface.si,
          accountScope: _scope.v2Namespace!,
          prompt: 'Compare my two options.',
          history: const [],
          context: {
            'language': 'en',
            'selectedSources': <String>[],
            'contextScope': 'chatOnly',
            'tasks': <Object?>[],
          },
          requestId: 'legacy-request-1',
        ),
        data: {
          'credits': 4,
          'digest': 'fixture',
          'proof': 'fixture',
          'policy': 'fixture',
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
        },
      );
      final stored = PendingConversationRequest(
        quote: quote,
        savedAt: DateTime.now(),
      );
      // Exactly the shape the previous version wrote: no choice marker.
      await SecureStore(backend: backend)
          .forAccount(_scope)
          .writeString(
            AssistantConversationRepository.storageKey,
            jsonEncode({
              'version': 1,
              'revision': 0,
              'messages': <Object?>[],
              'sources': <Object?>[],
              'pendingRequests': {'si': stored.toJson()},
            }),
          );
      final paid = <Map<String, dynamic>>[];
      var quotes = 0;
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) {
          quotes++;
          return _quote(body);
        }
        paid.add(body);
        return _answer(body['requestId'], 'The legacy paid reply.');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);

      expect(quotes, 0);
      expect(paid, hasLength(1));
      expect(
        jsonEncode(paid.single),
        jsonEncode({...quote.packet.toJson(), 'quote': quote.data}),
      );
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: a pending request older than the price lifetime is not re-sent and the user is told',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        final never = Completer<_Response>();
        final first = _setup((body) async {
          if (body['quoteOnly'] == true) {
            return _quote(body, valid: const Duration(seconds: 1));
          }
          return never.future;
        }, backend);
        await _pumpScreen(
          tester,
          first,
          ConversationSurface.si,
          language: language,
        );
        // Labels are English in the confirmation flow only for 'en'.
        if (language == 'en') {
          await _confirmPaidRequest(tester, 'Compare my two options.');
        } else {
          await _confirmPaidRequestSpanish(tester, 'Compara mis dos opciones.');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        first.dispose();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)),
        );

        var transportCalls = 0;
        final second = _setup((body) async {
          transportCalls++;
          throw StateError('An expired request must not be sent');
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          second.dispose();
        });
        await _pumpScreen(
          tester,
          second,
          ConversationSurface.si,
          language: language,
        );
        await _settle(tester);

        expect(transportCalls, 0);
        expect(
          find.textContaining(
            language == 'en'
                ? 'its reply can no longer be collected'
                : 'ya no se puede recuperar su respuesta',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('conversation-input')))
              .controller!
              .text,
          language == 'en'
              ? 'Compare my two options.'
              : 'Compara mis dos opciones.',
        );
        expect(await _storedChat(backend), isNot(contains('pendingRequests')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a pending request that cannot be rebuilt exactly is never re-sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final never = Completer<_Response>();
      final first = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        return never.future;
      }, backend);
      await _pumpScreen(tester, first, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();

      final raw = await _storedChat(backend);
      expect(raw, contains('pendingRequests'));
      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      final pending =
          (envelope['pendingRequests'] as Map<String, dynamic>)['si']
              as Map<String, dynamic>;
      // A body changed by a single space is a different request.
      pending['body'] = (pending['body'] as String).replaceFirst(
        '"prompt":"',
        '"prompt": "',
      );
      await SecureStore(backend: backend)
          .forAccount(_scope)
          .writeString(
            AssistantConversationRepository.storageKey,
            jsonEncode(envelope),
          );

      var transportCalls = 0;
      final second = _setup((body) async {
        transportCalls++;
        throw StateError('A changed request must not be sent');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);

      expect(transportCalls, 0);
      expect(
        find.textContaining('could not be restored on this device'),
        findsOneWidget,
      );
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  /// Confirms one paid request in a container whose transport never answers,
  /// then closes it, leaving the request stored as after an app restart.
  Future<Map<String, dynamic>> leavePendingRequest(
    WidgetTester tester,
    InMemorySecureStoreBackend backend, {
    ConversationSurface surface = ConversationSurface.si,
  }) async {
    final never = Completer<_Response>();
    final paid = <Map<String, dynamic>>[];
    final first = _setup((body) async {
      if (body['quoteOnly'] == true) return _quote(body);
      paid.add(body);
      return never.future;
    }, backend);
    await _pumpScreen(tester, first, surface);
    await _confirmPaidRequest(tester, 'Compare my two options.');
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    expect(paid, hasLength(1));
    return paid.single;
  }

  testWidgets(
    'an account change while recovery waits never sends the old account request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await leavePendingRequest(tester, backend);

      final other = AccountStorageScope.authenticated('synthetic-other');
      var active = _scope;
      final gate = Completer<void>();
      var transportCalls = 0;
      final second = _setup(
        (body) async {
          transportCalls++;
          throw StateError('Account A request must not be sent for B');
        },
        backend,
        readScope: () => active,
        releaseGate: gate,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      // Recovery is now waiting for release decisions. Switch accounts.
      active = other;
      second.invalidate(accountStorageScopeProvider);
      await tester.pump();
      gate.complete();
      await _settle(tester);

      expect(transportCalls, 0);
      // Account B sees nothing of A's request: no message, no retry offer,
      // no question in the box.
      expect(find.byKey(const Key('conversation-error')), findsNothing);
      expect(find.text('Retry same request'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        isEmpty,
      );
      // Account A keeps its request for when it returns.
      expect(await _storedChat(backend), contains('pendingRequests'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a recovered request answered with an expired price says so and restores the question',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await leavePendingRequest(tester, backend);

      var paid = 0;
      final second = _setup((body) async {
        paid++;
        return (
          status: 409,
          data: <String, dynamic>{
            'requestId': body['requestId'],
            'error': 'credit_quote_required',
          },
        );
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);

      expect(paid, 1);
      expect(
        find.textContaining('Your question is back in the box below'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        'Compare my two options.',
      );
      expect(find.text('Retry same request'), findsNothing);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a request is collected when the account becomes ready after the screen opens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await leavePendingRequest(tester, backend);

      var active = const AccountStorageScope.signedOut();
      var paid = 0;
      final second = _setup(
        (body) async {
          paid++;
          return _answer(body['requestId'], 'Collected once ready.');
        },
        backend,
        readScope: () => active,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);
      expect(paid, 0);

      active = _scope;
      second.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _settle(tester);

      expect(paid, 1);
      expect(find.text('Collected once ready.'), findsOneWidget);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Choose a step stores, sends and collects a request even when saved Chat is damaged, leaving Chat data as it was',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final store = SecureStore(backend: backend).forAccount(_scope);
      final damagedChat = <String, dynamic>{
        'version': 1,
        'revision': 4,
        'messages': [
          {'role': 'user', 'content': 'Kept as it was.'},
        ],
        'sources': ['unknown'],
      };
      await store.writeString(
        AssistantConversationRepository.storageKey,
        jsonEncode(damagedChat),
      );
      final reply = Completer<_Response>();
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        return reply.future;
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.planner);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      expect(paid, hasLength(1));
      expect(find.textContaining('could not be saved'), findsNothing);

      await _leave(tester, container);
      await _pumpScreen(tester, container, ConversationSurface.planner);
      reply.complete(_answer(paid.single['requestId'], 'Planner reply.'));
      await _settle(tester);

      expect(find.text('Planner reply.'), findsOneWidget);
      expect(paid, hasLength(1));
      final stored =
          jsonDecode((await _storedChat(backend))!) as Map<String, dynamic>;
      expect(stored, damagedChat);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'with the screen closed and the app running, a request is purged at its collect-by time but never while it still runs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final reply = Completer<_Response>();
      final container = _setup(
        (body) async {
          if (body['quoteOnly'] == true) {
            return _quote(body, valid: const Duration(seconds: 1));
          }
          return reply.future;
        },
        backend,
        fakeClockPurgeTimer: true,
        // A fresh scope object for the same account on every rebuild, as a
        // token refresh produces.
        readScope: () => AccountStorageScope.authenticated('synthetic-pending'),
      );
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      await _leave(tester, container);
      expect(await _storedChat(backend), contains('Compare my two options.'));
      // A same-account auth event between arming and firing rebuilds the
      // scope and the Chat repository; the purge must still work.
      container.invalidate(accountStorageScopeProvider);
      // Something reads the repository again, as screens and account
      // opening do, so a new instance replaces the one armed with.
      expect(
        container.read(assistantConversationHistoryRepositoryProvider),
        isNotNull,
      );
      await tester.pump();

      // The collect-by time passes on the real clock and the timer fires.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(
        await _storedChat(backend),
        contains('Compare my two options.'),
        reason: 'A request still running is never purged.',
      );

      // The run ends without a usable reply: nothing can be collected now.
      reply.complete((
        status: 503,
        data: <String, dynamic>{'error': 'service_unavailable'},
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      final purged = await _storedChat(backend);
      expect(purged, isNot(contains('Compare my two options.')));
      expect(purged, isNot(contains('"quote"')));
      expect(purged, contains('"expired":true'));
      expect(tester.takeException(), isNull);
      // The fake-clock timer belongs to the container; end it in the body.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'a request purged when the account became ready is still reported, without its content',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await leavePendingRequest(
        tester,
        backend,
        surface: ConversationSurface.planner,
      );
      // Age the stored request past its collect-by time, then run the purge
      // that account readiness runs.
      final store = SecureStore(backend: backend).forAccount(_scope);
      final envelope =
          jsonDecode(
                (await store.readString(
                  AssistantConversationRepository.storageKey,
                ))!,
              )
              as Map<String, dynamic>;
      final planner =
          (envelope['pendingRequests'] as Map<String, dynamic>)['planner']
              as Map<String, dynamic>;
      planner['savedAt'] = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      await store.writeString(
        AssistantConversationRepository.storageKey,
        jsonEncode(envelope),
      );
      var transportCalls = 0;
      final second = _setup((body) async {
        transportCalls++;
        throw StateError('An expired request must not be sent');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await tester.runAsync(
        () => second
            .read(assistantConversationHistoryRepositoryProvider)!
            .purgeExpiredPending(),
      );
      final purged = await _storedChat(backend);
      expect(purged, isNot(contains('Compare my two options.')));
      expect(purged, isNot(contains('"quote"')));
      expect(purged, contains('"expired":true'));

      await _pumpScreen(tester, second, ConversationSurface.planner);
      await _settle(tester);
      expect(transportCalls, 0);
      expect(find.textContaining('can no longer be collected'), findsOneWidget);
      expect(find.textContaining('back in the box'), findsNothing);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a confirmed request that cannot be stored first is not sent or charged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var paid = 0;
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid++;
        return _answer(body['requestId'], 'Must not be requested.');
      }, _ReadOnlyChatBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      await _settle(tester);
      expect(paid, 0);
      expect(
        find.textContaining('could not be saved on this device'),
        findsOneWidget,
      );
      expect(find.text('Retry same request'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a terminal server answer on return clears the pending request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = InMemorySecureStoreBackend();
    final never = Completer<_Response>();
    final first = _setup((body) async {
      if (body['quoteOnly'] == true) return _quote(body);
      return never.future;
    }, backend);
    await _pumpScreen(tester, first, ConversationSurface.si);
    await _confirmPaidRequest(tester, 'Compare my two options.');
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();

    var paid = 0;
    final second = _setup((body) async {
      paid++;
      return (
        status: 409,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'error': 'request_refunded',
        },
      );
    }, backend);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      second.dispose();
    });
    await _pumpScreen(tester, second, ConversationSurface.si);
    await _settle(tester);

    expect(paid, 1);
    expect(find.textContaining('credits were refunded'), findsOneWidget);
    expect(find.text('Retry same request'), findsNothing);
    expect(await _storedChat(backend), isNot(contains('pendingRequests')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'starting another request abandons the pending one so it is never re-sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final never = Completer<_Response>();
      final container = _setup(
        (body) async {
          if (body['quoteOnly'] == true) return _quote(body);
          return never.future;
        },
        backend,
        paidWaitTimeout: const Duration(milliseconds: 100),
      );
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      await tester.pump(const Duration(milliseconds: 150));
      final another = find.text('Start another request');
      await tester.scrollUntilVisible(
        another,
        120,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      // Built is not the same as on screen; the information row above the
      // input sits right below the list.
      await tester.ensureVisible(another);
      await tester.pump();
      await tester.tap(another);
      await _waitFor(tester, find.text('Start new request'));
      await tester.tap(find.text('Start new request'));
      await _settle(tester);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();

      var transportCalls = 0;
      final second = _setup((body) async {
        transportCalls++;
        throw StateError('An abandoned request must not be sent');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);
      expect(transportCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  /// Sends a first message at the button's price and accepts its preview,
  /// so the next message on the same selection is one tap.
  Future<void> firstMessage(WidgetTester tester) async {
    final input = find.byKey(const Key('conversation-input'));
    await tester.enterText(input, 'First question.');
    await tester.tap(find.byKey(const Key('conversation-send')));
    await _waitFor(tester, find.text('Send'));
    await tester.tap(find.text('Send'));
    await _waitFor(tester, find.text('First reply.'));
  }

  testWidgets(
    'a one-tap message at the shown price survives an app restart and is re-sent byte for byte once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final never = Completer<_Response>();
      final firstPaid = <Map<String, dynamic>>[];
      final first = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body, credits: 5);
        firstPaid.add(body);
        if (firstPaid.length == 1) {
          return _answer(body['requestId'], 'First reply.', credits: 5);
        }
        return never.future;
      }, backend);
      await _pumpScreen(tester, first, ConversationSurface.si);
      await firstMessage(tester);

      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'Compare my two options.',
      );
      await tester.tap(find.byKey(const Key('conversation-send')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // One tap: no preview and no price dialog.
      expect(find.byType(AlertDialog), findsNothing);
      expect(firstPaid, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();

      final secondPaid = <Map<String, dynamic>>[];
      var secondQuotes = 0;
      final second = _setup((body) async {
        if (body['quoteOnly'] == true) {
          secondQuotes++;
          return _quote(body, credits: 5);
        }
        secondPaid.add(body);
        return _answer(body['requestId'], 'The one-tap reply.', credits: 5);
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        second.dispose();
      });
      await _pumpScreen(tester, second, ConversationSurface.si);
      await _settle(tester);

      expect(secondQuotes, 0);
      expect(secondPaid, hasLength(1));
      expect(secondPaid.single['requestId'], firstPaid.last['requestId']);
      expect(jsonEncode(secondPaid.single), jsonEncode(firstPaid.last));
      expect(find.text('The one-tap reply.'), findsOneWidget);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  /// Sends one message up to the storing step and holds its storage at
  /// [hold] (the read before the write, or the write itself).
  Future<_GatedBackend> holdStoring(
    WidgetTester tester,
    ProviderContainer Function(_GatedBackend backend) create,
    _Hold hold, {
    ConversationSurface surface = ConversationSurface.si,
  }) async {
    final backend = _GatedBackend();
    final container = create(backend);
    addTearDown(() async {
      backend.release();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pumpScreen(tester, container, surface);
    await tester.enterText(
      find.byKey(const Key('conversation-input')),
      'Compare my two options.',
    );
    await tester.tap(find.byKey(const Key('conversation-send')));
    await _waitFor(tester, find.text('Send'));
    backend.armed = hold;
    await tester.tap(find.text('Send'));
    for (var i = 0; i < 30 && backend.held == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(backend.held, isNotNull, reason: 'Storing is held');
    // Let the preview finish closing.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return backend;
  }

  Future<void> tapStop(WidgetTester tester) async {
    final stop = find.byKey(const Key('conversation-stop-waiting'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pump();
  }

  const stoppedText =
      'Stopped before the request was sent for a reply. Nothing was charged. Your question is retained.';

  testWidgets(
    'stop while the request waits to be stored withdraws it: never stored, never sent, even after a restart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = <Map<String, dynamic>>[];
      Future<_Response> server(Map<String, dynamic> body) async {
        if (body['quoteOnly'] == true) return _quote(body, credits: 5);
        paid.add(body);
        return _answer(body['requestId'], 'Must not be sent.', credits: 5);
      }

      late ProviderContainer container;
      final backend = await holdStoring(
        tester,
        (backend) => container = _setup(server, backend),
        _Hold.read,
      );
      await tapStop(tester);
      expect(find.text(stoppedText), findsOneWidget);
      backend.release();
      await _settle(tester);
      expect(paid, isEmpty);
      expect(find.text(stoppedText), findsOneWidget);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));

      await _leave(tester, container);
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);
      final restarted = _setup(server, backend);
      addTearDown(restarted.dispose);
      await _pumpScreen(tester, restarted, ConversationSurface.si);
      await _settle(tester);
      expect(paid, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop while waiting to be stored, then a session change for the same account: never sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => _sessionGeneration = 1);
      final paid = <Map<String, dynamic>>[];
      late ProviderContainer container;
      final backend = await holdStoring(
        tester,
        (backend) => container = _setup((body) async {
          if (body['quoteOnly'] == true) return _quote(body, credits: 5);
          paid.add(body);
          return _answer(body['requestId'], 'Must not be sent.', credits: 5);
        }, backend),
        _Hold.read,
      );
      await tapStop(tester);
      _sessionGeneration = 2;
      container.invalidate(authSessionBoundaryProvider);
      await tester.pump();
      backend.release();
      await _settle(tester);
      expect(paid, isEmpty);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      // The reloaded chat has nothing to collect.
      await _leave(tester, container);
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);
      expect(paid, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop while waiting to be stored, then an account switch and return: never sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = <Map<String, dynamic>>[];
      var active = _scope;
      late ProviderContainer container;
      final backend = await holdStoring(
        tester,
        (backend) => container = _setup(
          (body) async {
            if (body['quoteOnly'] == true) return _quote(body, credits: 5);
            paid.add(body);
            return _answer(body['requestId'], 'Must not be sent.', credits: 5);
          },
          backend,
          readScope: () => active,
        ),
        _Hold.read,
      );
      await tapStop(tester);
      active = AccountStorageScope.authenticated('synthetic-other');
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      backend.release();
      await _settle(tester);
      active = _scope;
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _settle(tester);
      expect(paid, isEmpty);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop once the storage write has started says the request is finishing, and it is sent once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = <Map<String, dynamic>>[];
      final backend = await holdStoring(
        tester,
        (backend) => _setup((body) async {
          if (body['quoteOnly'] == true) return _quote(body, credits: 5);
          paid.add(body);
          return _answer(body['requestId'], 'The finished reply.', credits: 5);
        }, backend),
        _Hold.write,
      );
      await tapStop(tester);
      expect(find.textContaining('Nothing was charged'), findsNothing);
      expect(
        find.textContaining('The paid request is still finishing safely'),
        findsOneWidget,
      );
      backend.release();
      await _settle(tester);
      expect(paid, hasLength(1));
      expect(find.text('The finished reply.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name}: stop after the write started, then a sign-in change for the same account: told it is finishing, sent once, never "nothing was charged"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => _sessionGeneration = 1);
        final paid = <Map<String, dynamic>>[];
        // The reply waits, so whatever the screen says once storing has
        // ended stays on screen to be checked.
        final reply = Completer<_Response>();
        late ProviderContainer container;
        final backend = await holdStoring(
          tester,
          (backend) => container = _setup((body) async {
            if (body['quoteOnly'] == true) return _quote(body, credits: 5);
            paid.add(body);
            return reply.future;
          }, backend),
          _Hold.write,
          surface: surface,
        );
        await tapStop(tester);
        expect(
          find.textContaining('The paid request is still finishing safely'),
          findsOneWidget,
        );
        _sessionGeneration = 2;
        container.invalidate(authSessionBoundaryProvider);
        await tester.pump();
        backend.release();
        // At no point may the screen say it was not saved or not charged.
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          expect(find.textContaining('could not be saved'), findsNothing);
          expect(find.textContaining('No credits were charged'), findsNothing);
          expect(find.textContaining('Nothing was charged'), findsNothing);
        }
        expect(paid, hasLength(1));
        if (surface == ConversationSurface.planner) {
          // Choose a step keeps its screen through a sign-in change: what it
          // said at Stop stays true and on screen until the reply arrives.
          expect(
            find.textContaining('The paid request is still finishing safely'),
            findsOneWidget,
          );
        }
        reply.complete(
          _answer(paid.single['requestId'], 'The finished reply.', credits: 5),
        );
        await _settle(tester);
        expect(paid, hasLength(1));
        expect(find.text('The finished reply.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'stop after the write started, then an account switch and return: not sent on the other account, sent once on return',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = <Map<String, dynamic>>[];
      var active = _scope;
      late ProviderContainer container;
      final backend = await holdStoring(
        tester,
        (backend) => container = _setup(
          (body) async {
            if (body['quoteOnly'] == true) return _quote(body, credits: 5);
            paid.add(body);
            return _answer(
              body['requestId'],
              'The finished reply.',
              credits: 5,
            );
          },
          backend,
          readScope: () => active,
        ),
        _Hold.write,
      );
      await tapStop(tester);
      active = AccountStorageScope.authenticated('synthetic-other');
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      backend.release();
      await _settle(tester);
      expect(paid, isEmpty, reason: 'Never sent for the other account');
      expect(find.textContaining('Nothing was charged'), findsNothing);
      active = _scope;
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _settle(tester);
      expect(paid, hasLength(1));
      expect(find.text('The finished reply.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name}: a cleanup error after the request was written still sends it once and never says it was not saved',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = _GatedBackend();
        final paid = <Map<String, dynamic>>[];
        final container = _setup((body) async {
          if (body['quoteOnly'] == true) return _quote(body, credits: 5);
          paid.add(body);
          return _answer(body['requestId'], 'The stored reply.', credits: 5);
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(tester, container, surface);
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'Compare my two options.',
        );
        await tester.tap(find.byKey(const Key('conversation-send')));
        await _waitFor(tester, find.text('Send'));
        backend.failNextCleanup = true;
        await tester.tap(find.text('Send'));
        await _settle(tester);
        expect(find.textContaining('could not be saved'), findsNothing);
        expect(find.textContaining('No credits were charged'), findsNothing);
        expect(paid, hasLength(1));
        expect(find.text('The stored reply.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Task 4: the read-back after an ambiguous save is only for the request\'s own account',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paid = <Map<String, dynamic>>[];
      var active = _scope;
      late ProviderContainer container;
      final backend = await holdStoring(
        tester,
        (backend) => container = _setup(
          (body) async {
            if (body['quoteOnly'] == true) return _quote(body, credits: 5);
            paid.add(body);
            return _answer(body['requestId'], 'The stored reply.', credits: 5);
          },
          backend,
          readScope: () => active,
        ),
        _Hold.write,
      );
      backend.failNextCleanup = true;
      // Another account takes over; nothing is pumped before the write is
      // released, so the screen has not reacted yet.
      active = AccountStorageScope.authenticated('synthetic-other');
      container.invalidate(accountStorageScopeProvider);
      backend.release();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('could not be saved'), findsNothing);
        expect(
          find.textContaining('may or may not have been saved'),
          findsNothing,
        );
        expect(find.textContaining('No credits were charged'), findsNothing);
      }
      expect(paid, isEmpty, reason: 'Never sent for the other account');
      // Back on the first account, its stored request is collected once.
      active = _scope;
      container.invalidate(accountStorageScopeProvider);
      await tester.pump();
      await _settle(tester);
      expect(paid, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'when the stored request cannot be read back, the message allows both outcomes and the request is collected once later',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = _GatedBackend();
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body, credits: 5);
        paid.add(body);
        return _answer(body['requestId'], 'Collected later.', credits: 5);
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'Compare my two options.',
      );
      await tester.tap(find.byKey(const Key('conversation-send')));
      await _waitFor(tester, find.text('Send'));
      backend
        ..failNextCleanup = true
        ..failReadAfterCleanup = true;
      await tester.tap(find.text('Send'));
      await _settle(tester);
      expect(
        find.textContaining('may or may not have been saved on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('No credits were charged'), findsNothing);
      expect(paid, isEmpty);
      await _leave(tester, container);
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);
      expect(paid, hasLength(1));
      expect(find.text('Collected later.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop waiting before the request is stored stores nothing and sends nothing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final quote = Completer<_Response>();
      final paid = <Map<String, dynamic>>[];
      Map<String, dynamic>? quoted;
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) {
          quoted = body;
          return quote.future;
        }
        paid.add(body);
        return _answer(body['requestId'], 'Must not be sent.', credits: 5);
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'Compare my two options.',
      );
      await tester.tap(find.byKey(const Key('conversation-send')));
      await _waitFor(tester, find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pump(const Duration(milliseconds: 100));
      final stop = find.byKey(const Key('conversation-stop-waiting'));
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();
      expect(find.textContaining('Nothing was charged'), findsOneWidget);
      // The price arrives after stopping: nothing is stored or sent.
      expect(quoted, isNotNull);
      quote.complete(_quote(quoted!, credits: 5));
      await _settle(tester);
      expect(paid, isEmpty);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  /// A confirmed request left in storage by an earlier app run.
  Future<ConversationPacket> storeEarlierRunRequest(
    InMemorySecureStoreBackend backend,
    ConversationSurface surface,
  ) async {
    final packet = ConversationPacket(
      surface: surface,
      accountScope: _scope.v2Namespace!,
      prompt: 'Compare my two options.',
      history: const [],
      context: {
        'language': 'en',
        'selectedSources': <String>[],
        'contextScope': 'chatOnly',
        'tasks': <Object?>[],
      },
    );
    await AssistantConversationRepository(
      SecureStore(backend: backend).forAccount(_scope),
      isCurrent: () => true,
    ).savePending(
      PendingConversationRequest(
        quote: ConversationQuote(
          packet: packet,
          data: Map<String, dynamic>.from(
            _quote({'requestId': packet.requestId}).data['quote'] as Map,
          ),
        ),
        savedAt: DateTime.now(),
      ),
    );
    return packet;
  }

  testWidgets(
    'a recovered cached reply after a newer wallet read does not show the older balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final packet = await storeEarlierRunRequest(
        backend,
        ConversationSurface.si,
      );
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        // The server's cached reply from the original reservation: 20 left
        // then.
        return _answer(body['requestId'], 'The earlier paid reply.');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      // After the restart the person bought credits; Plans read the wallet.
      final known = container.read(aiCreditKnownBalanceProvider.notifier);
      known.reportWallet(_scope.v2Namespace, known.beginRead(), 120);
      expect(container.read(aiCreditKnownBalanceProvider), 120);

      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);
      expect(paid.single['requestId'], packet.requestId);
      expect(find.text('The earlier paid reply.'), findsOneWidget);
      // The reply keeps its own figure; the header shows no balance rather
      // than the older one.
      expect(
        find.textContaining('20 left after this reply', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('conversation-balance'), skipOffstage: false),
        findsNothing,
      );
      expect(container.read(aiCreditKnownBalanceProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving mid-request, buying credits and returning shows no older balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final reply = Completer<_Response>();
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        return reply.future;
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await _confirmPaidRequest(tester, 'Compare my two options.');
      expect(paid, hasLength(1));
      await _leave(tester, container);
      // Reserved and answered while away: 20 left then.
      reply.complete(_answer(paid.single['requestId'], 'The paid reply.'));
      await _settle(tester);
      // Then the person bought credits; Plans read the wallet.
      final known = container.read(aiCreditKnownBalanceProvider.notifier);
      known.walletChanged();
      known.reportWallet(_scope.v2Namespace, known.beginRead(), 120);
      expect(container.read(aiCreditKnownBalanceProvider), 120);

      await _pumpScreen(tester, container, ConversationSurface.si);
      await _settle(tester);
      expect(find.text('The paid reply.'), findsOneWidget);
      expect(paid, hasLength(1), reason: 'Joined, not sent again');
      expect(
        find.textContaining('20 left after this reply', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('conversation-balance'), skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name}: a recovered request refused with unauthorized does not say nothing was charged',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        await storeEarlierRunRequest(backend, surface);
        final paid = <Map<String, dynamic>>[];
        final container = _setup((body) async {
          if (body['quoteOnly'] == true) return _quote(body);
          paid.add(body);
          return (
            status: 401,
            data: <String, dynamic>{'error': 'unauthorized'},
          );
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(tester, container, surface);
        await _settle(tester);
        expect(paid, hasLength(1));
        final error = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('conversation-error')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(error, startsWith('Your sign-in needs renewing'));
        expect(error, contains('This request may already have been sent'));
        expect(error, contains('Check your balance before asking again.'));
        expect(error, isNot(contains('Nothing was charged')));
        expect(error, isNot(contains('No credits were charged')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: M10: the stored-request privacy line says an unshown reply keeps it until shown',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = _setup(
          (body) async => _quote(body),
          InMemorySecureStoreBackend(),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(
          tester,
          container,
          ConversationSurface.si,
          language: language,
        );
        await _settle(tester);
        final privacy = find.byKey(const Key('conversation-history-privacy'));
        await tester.scrollUntilVisible(
          privacy,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(privacy);
        await tester.pump();
        await tester.tap(
          find.text(
            language == 'es'
                ? 'Historial de Chat y privacidad'
                : 'Chat history & privacy',
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final pendingLine = find.byKey(
          const Key('conversation-pending-privacy'),
        );
        await tester.scrollUntilVisible(
          pendingLine,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        final line = tester.widget<Text>(pendingLine).data!;
        expect(
          line,
          contains(
            language == 'es'
                ? 'Una respuesta que llegó pero aún no se mostró la conserva hasta que se muestra; si la app se cierra antes, permanece en el dispositivo hasta la próxima vez que se abra esta cuenta y se borra entonces.'
                : 'A reply that arrived but was not yet shown keeps it until it is shown; if the app closes first, it stays on the device until this account is next opened, and is deleted then.',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: M2: Clear conversation says a paid request still finishing is removed too',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        final never = Completer<_Response>();
        final container = _setup(
          (body) async {
            if (body['quoteOnly'] == true) return _quote(body);
            return never.future;
          },
          backend,
          paidWaitTimeout: const Duration(seconds: 2),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(
          tester,
          container,
          ConversationSurface.si,
          language: language,
        );
        if (language == 'es') {
          await _confirmPaidRequestSpanish(tester, 'Compara mis opciones.');
        } else {
          await _confirmPaidRequest(tester, 'Compare my two options.');
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 300));
        final privacy = find.byKey(const Key('conversation-history-privacy'));
        await tester.ensureVisible(privacy);
        await tester.tap(privacy);
        await tester.pump(const Duration(milliseconds: 400));
        final clear = tester.widget<TextButton>(
          find.byKey(const Key('conversation-clear-history')),
        );
        expect(clear.onPressed, isNotNull);
        clear.onPressed!();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.textContaining(
            language == 'es'
                ? 'Borrar también la elimina: su respuesta no se mostrará y es posible que haya usado créditos.'
                : 'Clearing also removes it: its reply will not be shown, and it may have used credits.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: M6: a request too large to build gets the shorten text, nothing sent',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        // Saved messages whose characters grow sixfold in the request's JSON.
        final heavy = List.filled(2500, '\u0001').join();
        await SecureStore(backend: backend)
            .forAccount(_scope)
            .writeString(
              AssistantConversationRepository.storageKey,
              jsonEncode({
                'version': 1,
                'revision': 0,
                'messages': [
                  for (var i = 0; i < 2; i++)
                    {'role': i.isEven ? 'user' : 'assistant', 'content': heavy},
                ],
                'sources': <Object?>[],
                'sourcesChosen': true,
              }),
            );
        var calls = 0;
        final container = _setup((body) async {
          calls++;
          return _quote(body);
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(
          tester,
          container,
          ConversationSurface.si,
          language: language,
        );
        await _settle(tester);
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'Compare my two options.',
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('conversation-send')));
        await tester.tap(find.byKey(const Key('conversation-send')));
        await _settle(tester);
        expect(calls, 0);
        await tester.scrollUntilVisible(
          find.byKey(const Key('conversation-error')),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        final error = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('conversation-error')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(
          error,
          contains(
            language == 'es'
                ? 'Acorta la pregunta o elige menos información'
                : 'Shorten the question or choose less information',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // I1: the server answers request_reserved while the first call of the same
  // request id is still running.
  _Response stillReserved(Map<String, dynamic> body) => (
    status: 409,
    data: <String, dynamic>{
      'requestId': body['requestId'],
      'remainingCredits': 20,
      'error': 'request_reserved',
    },
  );
  const stillOnItsWay =
      'This same request is still being answered from its first attempt. The app checks again here every few seconds, and checking costs nothing more. Your question is kept.';
  Future<void> pumpSome(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name}: a recovered request still being answered is kept, said truthfully and collected again with the same id',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = InMemorySecureStoreBackend();
        await storeEarlierRunRequest(backend, surface);
        final paid = <Map<String, dynamic>>[];
        final container = _setup((body) async {
          if (body['quoteOnly'] == true) return _quote(body);
          paid.add(body);
          if (paid.length == 1) return stillReserved(body);
          return _answer(body['requestId'], 'The reply that was on its way.');
        }, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pumpScreen(tester, container, surface);
        await pumpSome(tester);
        expect(paid, hasLength(1));
        expect(find.text(stillOnItsWay), findsOneWidget);
        expect(find.textContaining('could not complete'), findsNothing);
        expect(await _storedChat(backend), contains('pendingRequests'));

        await tester.pump(const Duration(seconds: 5));
        await _settle(tester);
        expect(paid, hasLength(2));
        expect(paid.map(jsonEncode).toSet(), hasLength(1));
        expect(find.text('The reply that was on its way.'), findsOneWidget);
        expect(find.text(stillOnItsWay), findsNothing);
        expect(await _storedChat(backend), isNot(contains('pendingRequests')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'es: Chat after a sign-in change: the re-sent request still being answered is collected again, never charged twice',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => _sessionGeneration = 1);
      final backend = InMemorySecureStoreBackend();
      final first = Completer<_Response>();
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        if (paid.length == 1) return first.future;
        if (paid.length == 2) return stillReserved(body);
        return _answer(body['requestId'], 'La respuesta que seguía en camino.');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(
        tester,
        container,
        ConversationSurface.si,
        language: 'es',
      );
      await _confirmPaidRequestSpanish(tester, 'Compara mis dos opciones.');
      await pumpSome(tester);
      expect(paid, hasLength(1));

      // The same account signs in again while the first call is running.
      _sessionGeneration = 2;
      container.invalidate(authSessionBoundaryProvider);
      await pumpSome(tester);
      expect(paid, hasLength(2));
      expect(
        find.text(
          'Esta misma solicitud aún se está respondiendo desde su primer intento. La app vuelve a comprobarlo aquí cada pocos segundos y comprobarlo no cuesta nada más. Tu pregunta se conserva.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
      expect(paid, hasLength(3));
      expect(paid.map((b) => b['requestId']).toSet(), hasLength(1));
      expect(find.text('La respuesta que seguía en camino.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a request still being answered when it can no longer be collected falls back to the expired text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await storeEarlierRunRequest(backend, ConversationSurface.si);
      final paid = <Map<String, dynamic>>[];
      var shift = Duration.zero;
      final container = _setup(
        (body) async {
          if (body['quoteOnly'] == true) return _quote(body);
          paid.add(body);
          return stillReserved(body);
        },
        backend,
        clock: () => DateTime.now().add(shift),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await pumpSome(tester);
      expect(find.text(stillOnItsWay), findsOneWidget);
      // Still collectable: collected again, still being answered.
      await tester.pump(const Duration(seconds: 5));
      await pumpSome(tester);
      expect(paid, hasLength(2));
      expect(find.text(stillOnItsWay), findsOneWidget);

      shift = const Duration(minutes: 6);
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
      expect(paid, hasLength(2), reason: 'Nothing sent after the deadline');
      expect(
        find.textContaining('its reply can no longer be collected'),
        findsOneWidget,
      );
      expect(find.text(stillOnItsWay), findsNothing);
      expect(find.text('Retry same request'), findsNothing);
      expect(await _storedChat(backend), isNot(contains('pendingRequests')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'N3: too many requests while a request is still being answered means collect again later',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await storeEarlierRunRequest(backend, ConversationSurface.si);
      final paid = <Map<String, dynamic>>[];
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        if (paid.length == 1) return stillReserved(body);
        if (paid.length == 2) {
          return (
            status: 429,
            data: <String, dynamic>{'error': 'rate_limit_exceeded'},
          );
        }
        return _answer(body['requestId'], 'The reply that was on its way.');
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await pumpSome(tester);
      expect(find.text(stillOnItsWay), findsOneWidget);
      // Not before five seconds.
      await tester.pump(const Duration(seconds: 3));
      expect(paid, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await pumpSome(tester);
      expect(paid, hasLength(2));
      expect(find.text(stillOnItsWay), findsOneWidget);
      expect(find.textContaining('Too many AI requests'), findsNothing);
      expect(await _storedChat(backend), contains('pendingRequests'));
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
      expect(paid, hasLength(3));
      expect(paid.map(jsonEncode).toSet(), hasLength(1));
      expect(find.text('The reply that was on its way.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'N9: a timed re-collect keeps the still-answering line and does not move the list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await storeEarlierRunRequest(backend, ConversationSurface.si);
      final paid = <Map<String, dynamic>>[];
      final never = Completer<_Response>();
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        if (paid.length == 1) return stillReserved(body);
        return never.future;
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await pumpSome(tester);
      expect(find.text(stillOnItsWay), findsOneWidget);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await pumpSome(tester);
      expect(paid, hasLength(2), reason: 'The re-collect is in flight');
      expect(position.pixels, 0);
      await tester.scrollUntilVisible(
        find.text(stillOnItsWay),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(stillOnItsWay), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'N1: Clear conversation while a re-collect starts leaves Chat usable and never says nothing was charged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      await storeEarlierRunRequest(backend, ConversationSurface.si);
      final paid = <Map<String, dynamic>>[];
      final never = Completer<_Response>();
      final container = _setup((body) async {
        if (body['quoteOnly'] == true) return _quote(body);
        paid.add(body);
        if (paid.length == 1) return stillReserved(body);
        return never.future;
      }, backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pumpScreen(tester, container, ConversationSurface.si);
      await pumpSome(tester);
      expect(paid, hasLength(1));
      final privacy = find.byKey(const Key('conversation-history-privacy'));
      await tester.scrollUntilVisible(
        privacy,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(privacy);
      await tester.pump();
      await tester.tap(find.text('Chat history & privacy'));
      await tester.pump(const Duration(milliseconds: 400));
      final clear = tester.widget<TextButton>(
        find.byKey(const Key('conversation-clear-history')),
      );
      clear.onPressed!();
      await tester.pump(const Duration(milliseconds: 400));
      // The re-collect starts while the dialog is open.
      await tester.pump(const Duration(seconds: 6));
      await pumpSome(tester);
      expect(paid, hasLength(2));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Clear conversation'),
        ),
      );
      await pumpSome(tester);
      await tester.pump(const Duration(seconds: 6));
      await pumpSome(tester);
      expect(find.text('Preparing your response…'), findsNothing);
      expect(find.byKey(const Key('conversation-stop-waiting')), findsNothing);
      expect(find.textContaining('Nothing was charged'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .enabled,
        isTrue,
      );
      expect(paid, hasLength(2), reason: 'Nothing more is collected');
      expect(tester.takeException(), isNull);
    },
  );
}

enum _Hold { read, write }

/// Holds the next Chat-store read or write (storing the confirmed request
/// reads first, then writes) until released.
class _GatedBackend extends InMemorySecureStoreBackend {
  _Hold? armed;
  Completer<void>? held;
  // The cleanup after the next Chat-store write fails, as when the legacy
  // marker cannot be removed after the value was written.
  bool failNextCleanup = false;
  // The next Chat-store read after that cleanup failure fails too.
  bool failReadAfterCleanup = false;
  bool _failNextRead = false;

  void release() {
    final gate = held;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> _maybeHold(_Hold kind, String key) async {
    if (armed == kind &&
        key.startsWith(AssistantConversationRepository.storageKey)) {
      armed = null;
      held = Completer<void>();
      await held!.future;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    // SecureStore names the marker after the base64 of the key.
    if (failNextCleanup &&
        key.contains(
          base64UrlEncode(
            utf8.encode(AssistantConversationRepository.storageKey),
          ),
        )) {
      failNextCleanup = false;
      _failNextRead = failReadAfterCleanup;
      throw StateError('synthetic_cleanup_failure');
    }
    return super.delete(key: key);
  }

  @override
  Future<String?> read({required String key}) async {
    if (_failNextRead &&
        key.startsWith(AssistantConversationRepository.storageKey)) {
      _failNextRead = false;
      throw StateError('synthetic_read_failure');
    }
    await _maybeHold(_Hold.read, key);
    return super.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    await _maybeHold(_Hold.write, key);
    return super.write(key: key, value: value);
  }
}

class _ReadOnlyChatBackend extends InMemorySecureStoreBackend {
  @override
  Future<void> write({required String key, required String value}) async {
    if (key.startsWith(AssistantConversationRepository.storageKey)) {
      throw StateError('synthetic_local_write_failure');
    }
    return super.write(key: key, value: value);
  }
}

Future<void> _confirmPaidRequestSpanish(
  WidgetTester tester,
  String prompt,
) async {
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 40; i++) {
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.enterText(input, prompt);
  await tester.tap(find.byKey(const Key('conversation-send')));
  await _waitFor(tester, find.text('Enviar'));
  await tester.tap(find.text('Enviar'));
  await _waitFor(tester, find.text('Usar 4 créditos'));
  await tester.tap(find.text('Usar 4 créditos'));
  // Let the confirmation dialog finish closing before anything else.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Consent extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() =>
      const PersonalizationProfile(externalAiAllowed: true);
}

/// A session-boundary change for the same account raises this.
var _sessionGeneration = 1;

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => AuthSessionBoundary(
    generation: _sessionGeneration,
    userId: 'synthetic-pending',
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
