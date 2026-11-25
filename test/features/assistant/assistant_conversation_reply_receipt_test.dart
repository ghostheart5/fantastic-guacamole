import 'dart:async';

import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
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
import 'package:go_router/go_router.dart';

// Every AI reply says what it used, what it cost and what is left; the
// balance is in the header once the app knows it; running out of credits
// offers a way to get more; being offline is said before anything starts.

typedef _Response = ({int status, Map<String, dynamic> data});

final _scope = AccountStorageScope.authenticated('synthetic-receipt');
final _records = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    description: 'Milk, rice and vegetables for dinner.',
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
const _receipt = Key('conversation-reply-receipt');
const _balance = Key('conversation-balance');
const _getCredits = Key('conversation-get-credits');

Map<String, dynamic> _quote(Map<String, dynamic> body) => {
  'requestId': body['requestId'],
  'quote': <String, dynamic>{
    'credits': conversationMessageCredits,
    'digest': 'fixture',
    'proof': 'fixture',
    'policy': 'fixture',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .millisecondsSinceEpoch,
  },
};

class _Server {
  _Server({this.balance = 25, this.quoteFailure, this.paidFailure});
  int balance;
  final _Response? quoteFailure;
  final _Response? paidFailure;
  int quotes = 0;
  final paid = <Map<String, dynamic>>[];

  Future<_Response> call(Map<String, dynamic> body) async {
    if (body['quoteOnly'] == true) {
      quotes++;
      return quoteFailure ?? (status: 200, data: _quote(body));
    }
    paid.add(body);
    if (paidFailure case final _Response failure) return failure;
    if (balance < conversationMessageCredits) {
      return (
        status: 402,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'error': 'insufficient_credits',
          'remainingCredits': balance,
        },
      );
    }
    balance -= conversationMessageCredits;
    return (
      status: 200,
      data: <String, dynamic>{
        'requestId': body['requestId'],
        'message': 'Reply ${paid.length}.',
        'creditsCharged': conversationMessageCredits,
        'remainingCredits': balance,
        'model': 'transport-fixture',
      },
    );
  }
}

ProviderContainer _setup(
  _Server server,
  InMemorySecureStoreBackend backend, {
  bool purchasing = true,
  NetworkInterfaceAvailability? network,
  Future<AiCreditWallet> Function()? wallet,
}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
    accountStorageScopeProvider.overrideWith((ref) => _scope),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(server.call),
    subscriptionPurchasingEnabledProvider.overrideWithValue(purchasing),
    if (network != null)
      networkStatusProvider.overrideWith(
        (ref) => Stream.value(NetworkStatus(interfaceAvailability: network)),
      ),
    if (wallet != null) ...[
      aiCreditWalletFromServerProvider.overrideWithValue(true),
      aiCreditWalletProvider.overrideWith((ref) => wallet()),
    ],
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

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  double textScale = 1,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AssistantConversationScreen(
          surface: ConversationSurface.si,
          onLocalTools: () {},
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) =>
            const Scaffold(body: Text('Synthetic plans and credits')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
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

/// Types [prompt], taps send and accepts the preview if it opens.
Future<void> _ask(WidgetTester tester, String prompt, String language) async {
  await tester.enterText(find.byKey(const Key('conversation-input')), prompt);
  await tester.pump();
  await tester.ensureVisible(find.byKey(_send));
  await tester.tap(find.byKey(_send));
  await _settle(tester);
  final accept = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(language == 'es' ? 'Enviar' : 'Send'),
  );
  if (accept.evaluate().isNotEmpty) {
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await _settle(tester);
  }
}

List<String> _receipts(WidgetTester tester) => tester
    .widgetList<Text>(find.byKey(_receipt))
    .map((text) => text.data!)
    .toList();

String? _balanceText(WidgetTester tester) {
  final found = find.byKey(_balance);
  return found.evaluate().isEmpty ? null : tester.widget<Text>(found).data;
}

String _errorText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('conversation-error')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  for (final language in ['en', 'es']) {
    final es = language == 'es';
    testWidgets(
      '$language: each reply shows what its sent packet used, its cost and what is left',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server();
        final backend = InMemorySecureStoreBackend();
        final container = _setup(server, backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        // Nothing is known yet, and nothing is fetched to find out.
        expect(_balanceText(tester), isNull);

        await _ask(tester, 'When should I do the Grocery list?', language);
        expect(server.paid, hasLength(1));
        expect(_receipts(tester), [
          es
              ? 'Usó: tu pregunta, 1 tarea · Costo: 5 créditos · Quedan 20 créditos'
              : 'Used: your question, 1 task · Cost: 5 credits · 20 credits left',
        ]);
        expect(
          _balanceText(tester),
          es ? 'Tu saldo: 20 créditos' : 'Your balance: 20 credits',
        );

        // The second request also carried the first question and reply.
        await _ask(tester, 'And after that?', language);
        expect(server.paid, hasLength(2));
        expect(
          _receipts(tester).last,
          es
              ? 'Usó: tu pregunta, 1 tarea, 2 mensajes anteriores · Costo: 5 créditos · Quedan 15 créditos'
              : 'Used: your question, 1 task, 2 earlier messages · Cost: 5 credits · 15 credits left',
        );
        expect(
          _balanceText(tester),
          es ? 'Tu saldo: 15 créditos' : 'Your balance: 15 credits',
        );
        expect(container.exists(aiCreditWalletProvider), isFalse);

        // Saved with the chat: a fresh screen shows the same footers.
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, container, language: language);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        expect(_receipts(tester), hasLength(2));
        expect(
          _receipts(tester).last,
          contains(es ? 'Quedan 15' : '15 credits left'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a recovered reply shows what its own stored request carried', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final server = _Server(balance: 12);
    final backend = InMemorySecureStoreBackend();
    final packet = ConversationPacket(
      surface: ConversationSurface.si,
      accountScope: _scope.v2Namespace!,
      prompt: 'Which goal comes first?',
      history: const [
        {'role': 'user', 'content': 'Earlier question'},
        {'role': 'assistant', 'content': 'Earlier answer'},
      ],
      context: {
        'selectedSources': ['goals'],
        'tasks': const <Object?>[],
        'goals': [
          {'id': 'g1', 'title': 'Run a 10k'},
          {'id': 'g2', 'title': 'Read more'},
        ],
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
            _quote({'requestId': packet.requestId})['quote'] as Map,
          ),
        ),
        savedAt: DateTime.now(),
      ),
    );
    final container = _setup(server, backend);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await _settle(tester);
    expect(server.quotes, 0);
    expect(server.paid.single['requestId'], packet.requestId);
    expect(
      _receipts(tester).single,
      'Used: your question, 2 goals, 2 earlier messages · Cost: 5 credits · 7 credits left',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a balance the app already loaded is shown without a new read', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var walletReads = 0;
    final container = _setup(
      _Server(balance: 40),
      InMemorySecureStoreBackend(),
      wallet: () async {
        walletReads++;
        return AiCreditWallet(
          balance: 42,
          tier: 'free',
          allowance: 50,
          resetAt: DateTime(2026, 12),
          updatedAt: DateTime(2026, 11),
        );
      },
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    // Loaded earlier elsewhere in the app (Settings, for example).
    await container.read(aiCreditWalletProvider.future);
    await _pump(tester, container);
    expect(_balanceText(tester), 'Your balance: 42 credits');
    await _ask(tester, 'When should I do the Grocery list?', 'en');
    // The reply's own figure replaces it; the wallet is not read again.
    expect(_balanceText(tester), 'Your balance: 35 credits');
    expect(walletReads, 1);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'es']) {
    final es = language == 'es';
    testWidgets(
      '$language: out of credits says what is left and Get credits opens the plans screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(
          paidFailure: (
            status: 402,
            data: <String, dynamic>{
              'error': 'insufficient_credits',
              'remainingCredits': 3,
            },
          ),
        );
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await _ask(tester, 'When should I do the Grocery list?', language);
        expect(server.paid, hasLength(1));
        final message = _errorText(tester);
        expect(
          message,
          contains(
            es
                ? 'No tienes suficientes créditos de IA para este mensaje: tienes 3 y necesita 5.'
                : 'You do not have enough AI credits for this message: you have 3 and it needs 5.',
          ),
        );
        expect(
          message,
          contains(es ? 'No se cobraron créditos' : 'No credits were charged'),
        );
        expect(
          _balanceText(tester),
          es ? 'Tu saldo: 3 créditos' : 'Your balance: 3 credits',
        );
        final button = find.byKey(_getCredits);
        expect(
          find.descendant(
            of: button,
            matching: find.text(es ? 'Conseguir créditos' : 'Get credits'),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Synthetic plans and credits'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language: out of credits in a build that cannot sell credits says so plainly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(
          paidFailure: (
            status: 402,
            data: <String, dynamic>{'error': 'insufficient_credits'},
          ),
        );
        final container = _setup(
          server,
          InMemorySecureStoreBackend(),
          purchasing: false,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await _ask(tester, 'When should I do the Grocery list?', language);
        final message = _errorText(tester);
        expect(
          message,
          contains(
            es
                ? 'Comprar créditos no está disponible en esta versión de la app.'
                : 'Buying credits is not available in this version of the app.',
          ),
        );
        // The server sent no balance, so none is claimed.
        expect(message, isNot(contains(es ? ': tienes' : ': you have')));
        expect(find.byKey(_getCredits), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language: offline is said before anything starts and nothing is reserved',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server();
        final backend = InMemorySecureStoreBackend();
        final container = _setup(
          server,
          backend,
          network: NetworkInterfaceAvailability.unavailable,
        );
        // The app shell keeps the connection status running.
        container.listen(networkStatusProvider, (_, _) {});
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'When should I do the Grocery list?',
        );
        await tester.pump();
        await tester.tap(find.byKey(_send));
        await _settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(server.quotes, 0);
        expect(server.paid, isEmpty);
        final stored = await SecureStore(backend: backend)
            .forAccount(_scope)
            .readString(AssistantConversationRepository.storageKey);
        expect(stored ?? '', isNot(contains('pendingRequests')));
        final message = _errorText(tester);
        expect(
          message,
          startsWith(es ? 'No tienes conexión.' : 'You are offline.'),
        );
        expect(message, isNot(contains(es ? 'pago' : 'payment')));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('conversation-input')))
              .controller!
              .text,
          'When should I do the Grocery list?',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failure in <String, ({int status, String en, String es})>{
    'request_too_large': (
      status: 413,
      en: 'too large to send',
      es: 'demasiado grandes para enviarlas',
    ),
    'unauthorized': (
      status: 401,
      en: 'Sign in again',
      es: 'Inicia sesión de nuevo',
    ),
    'internal_ai_access_required': (
      status: 403,
      en: 'not available for this account right now',
      es: 'no está disponible para esta cuenta en este momento',
    ),
  }.entries) {
    for (final language in ['en', 'es']) {
      testWidgets('$language: ${failure.key} has its own plain message', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(
          quoteFailure: (
            status: failure.value.status,
            data: <String, dynamic>{'error': failure.key},
          ),
        );
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await _ask(tester, 'When should I do the Grocery list?', language);
        expect(server.paid, isEmpty);
        final message = _errorText(tester);
        expect(
          message,
          contains(language == 'es' ? failure.value.es : failure.value.en),
        );
        expect(
          message,
          contains(
            language == 'es' ? 'No se cobró nada' : 'Nothing was charged',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: at 320x640 and 200 percent text the footer, balance and Get credits fit',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(balance: 8);
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language, textScale: 2);
        await _ask(tester, 'When should I do the Grocery list?', language);
        expect(tester.takeException(), isNull);
        expect(server.paid, hasLength(1));
        await tester.ensureVisible(find.byKey(_receipt, skipOffstage: false));
        await tester.pump();
        // Taller than the conversation's space at this size: it scrolls
        // into view from its start.
        expect(
          find.byKey(_receipt).hitTestable(at: const Alignment(-0.9, -0.9)),
          findsOneWidget,
        );
        // At large text the balance is at the top of the conversation, so
        // the fixed area above it stays small.
        final balance = find.byKey(_balance, skipOffstage: false);
        await tester.drag(find.byType(ListView), const Offset(0, 5000));
        await tester.pump();
        await tester.ensureVisible(balance);
        await tester.pump();
        expect(find.byKey(_balance).hitTestable(), findsOneWidget);
        expect(
          tester.getRect(balance).top,
          greaterThanOrEqualTo(tester.getRect(find.byType(ListView)).top),
        );

        // 3 left: the next message is refused for lack of credits.
        await _ask(tester, 'And after that?', language);
        expect(server.paid, hasLength(2));
        expect(tester.takeException(), isNull);
        // The list was scrolled to its top above; go back to its end.
        for (var i = 0; i < 3; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -5000));
          await tester.pump();
        }
        final button = find.byKey(_getCredits);
        await tester.ensureVisible(
          find.byKey(_getCredits, skipOffstage: false),
        );
        await tester.pump();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('credits owed from a refunded purchase have their own message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final server = _Server(
      paidFailure: (
        status: 402,
        data: <String, dynamic>{
          'error': 'refunded_credits_outstanding',
          'remainingCredits': 0,
        },
      ),
    );
    final container = _setup(server, InMemorySecureStoreBackend());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await _ask(tester, 'When should I do the Grocery list?', 'en');
    expect(_errorText(tester), contains('refunded purchase'));
    expect(_errorText(tester), contains('No credits were charged'));
    expect(find.byKey(_getCredits), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
    userId: 'synthetic-receipt',
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
