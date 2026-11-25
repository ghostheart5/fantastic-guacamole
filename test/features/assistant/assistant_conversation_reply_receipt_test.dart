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
    // A fixed time far ahead: the price never expires during a test.
    'expiresAt': _quoteExpiry.millisecondsSinceEpoch,
  },
};
final _quoteExpiry = DateTime.utc(2100);

class _Server {
  _Server({
    this.balance = 25,
    this.quoteFailure,
    this.paidFailure,
    List<Object>? paidScript,
    this.message,
  }) : paidScript = paidScript ?? [];
  int balance;
  final _Response? quoteFailure;
  final _Response? paidFailure;

  /// Answers for the next paid calls, in order: a response, or an error the
  /// transport throws. Normal replies follow once it is used up.
  final List<Object> paidScript;
  final String? message;
  int quotes = 0;
  final paid = <Map<String, dynamic>>[];

  Future<_Response> call(Map<String, dynamic> body) async {
    if (body['quoteOnly'] == true) {
      quotes++;
      return quoteFailure ?? (status: 200, data: _quote(body));
    }
    paid.add(body);
    if (paidScript.isNotEmpty) {
      final next = paidScript.removeAt(0);
      if (next is Future<_Response>) return next;
      if (next is _Response) return next;
      throw next as Error;
    }
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
        'message': message ?? 'Reply ${paid.length}.',
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
  Future<Map<String, dynamic>> Function(String? account)? walletRow,
  AccountStorageScope Function()? readScope,
  Duration? paidWaitTimeout,
}) => ProviderContainer(
  overrides: [
    if (paidWaitTimeout != null)
      conversationPaidWaitTimeoutProvider.overrideWithValue(paidWaitTimeout),
    secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? _scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(server.call),
    subscriptionPurchasingEnabledProvider.overrideWithValue(purchasing),
    if (network != null)
      networkStatusProvider.overrideWith(
        (ref) => Stream.value(NetworkStatus(interfaceAvailability: network)),
      ),
    // The server wallet path with only the network read replaced.
    if (walletRow != null)
      aiCreditWalletProvider.overrideWith((ref) {
        final account = ref.watch(accountStorageScopeProvider).v2Namespace;
        return loadServerAiCreditWallet(ref, () => walletRow(account));
      }),
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
              ? 'Usó: tu pregunta, 1 tarea · Costo: 5 créditos · Quedan 20 después de esta respuesta'
              : 'Used: your question, 1 task · Cost: 5 credits · 20 left after this reply',
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
              ? 'Usó: tu pregunta, 1 tarea, 2 mensajes anteriores · Costo: 5 créditos · Quedan 15 después de esta respuesta'
              : 'Used: your question, 1 task, 2 earlier messages · Cost: 5 credits · 15 left after this reply',
        );
        // The receipt stays on this device: the earlier messages sent with
        // the second question carry only who said what.
        final sentHistory = server.paid.last['history'] as List;
        expect(sentHistory, hasLength(2));
        for (final turn in sentHistory) {
          expect((turn as Map).keys.toSet(), {'role', 'content'});
        }
        expect(server.paid.last.toString(), isNot(contains('creditsCharged')));
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
          contains(es ? 'Quedan 15' : '15 left after this reply'),
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
        // Recovery compares this with the device clock (there is no
        // injectable clock), so it must be the current time; the price's
        // expiry above is a fixed time.
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
      'Used: your question, 2 goals, 2 earlier messages · Cost: 5 credits · 7 left after this reply',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a balance the app already loaded is shown without a new read', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var walletReads = 0;
    final server = _Server(balance: 42);
    final container = _setup(
      server,
      InMemorySecureStoreBackend(),
      walletRow: (_) async {
        walletReads++;
        return {'balance': server.balance};
      },
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    // Read earlier elsewhere in the app (Settings, for example), which keeps
    // watching it.
    container.listen(aiCreditWalletProvider, (_, _) {});
    await container.read(aiCreditWalletProvider.future);
    await _pump(tester, container);
    expect(_balanceText(tester), 'Your balance: 42 credits');
    expect(walletReads, 1, reason: 'Opening Chat reads nothing');
    await _ask(tester, 'When should I do the Grocery list?', 'en');
    // The reply's own figure replaces it (Settings' refresh agrees).
    expect(_balanceText(tester), 'Your balance: 37 credits');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reopening Chat after a reply, with a previously loaded wallet, makes no wallet read',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var walletReads = 0;
      final server = _Server(balance: 40);
      final container = _setup(
        server,
        InMemorySecureStoreBackend(),
        walletRow: (_) async {
          walletReads++;
          return {'balance': server.balance};
        },
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      // Settings read the wallet once and has since closed.
      await container.read(aiCreditWalletProvider.future);
      expect(walletReads, 1);
      await _pump(tester, container);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      // The reply marked the wallet for a fresh read where it is next needed.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, container);
      await _settle(tester);
      expect(_balanceText(tester), 'Your balance: 35 credits');
      expect(walletReads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'after an account switch the Chat header shows no balance until the new account\'s wallet resolves',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var current = _scope;
      final other = AccountStorageScope.authenticated('synthetic-other');
      final newWallet = Completer<Map<String, dynamic>>();
      final container = _setup(
        _Server(balance: 40),
        InMemorySecureStoreBackend(),
        readScope: () => current,
        walletRow: (account) async =>
            account == other.v2Namespace ? newWallet.future : {'balance': 42},
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      // Settings is open beside Chat and keeps the wallet loaded.
      container.listen(aiCreditWalletProvider, (_, _) {});
      await container.read(aiCreditWalletProvider.future);
      await _pump(tester, container);
      expect(_balanceText(tester), 'Your balance: 42 credits');

      current = other;
      container.invalidate(accountStorageScopeProvider);
      // Every frame from the switch on: nothing from the first account.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(_balanceText(tester), isNull, reason: 'frame $i');
      }
      newWallet.complete({'balance': 7});
      await _settle(tester);
      expect(_balanceText(tester), 'Your balance: 7 credits');
      expect(tester.takeException(), isNull);
    },
  );

  group('known balance: one row of the rule each', () {
    late ProviderContainer container;
    late AiCreditKnownBalance known;
    final account = _scope.v2Namespace!;
    int? shown() => container.read(aiCreditKnownBalanceProvider);
    void wallet(int balance) =>
        known.reportWallet(account, known.beginRead(), balance);

    setUp(() {
      container = _setup(_Server(), InMemorySecureStoreBackend());
      known = container.read(aiCreditKnownBalanceProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('a wallet read with nothing running sets it', () {
      wallet(42);
      expect(shown(), 42);
    });

    test('a wallet read for another account is ignored', () {
      wallet(42);
      known.reportWallet('someone-else', known.beginRead(), 9);
      expect(shown(), 42);
    });

    test('a wallet read that began before a later event is not taken', () {
      final token = known.beginRead();
      known.walletChanged();
      known.reportWallet(account, token, 42);
      expect(shown(), isNull);
    });

    test('a request entering the paid step forgets it', () {
      wallet(42);
      known.enterPaid(account, 'a', firstAttempt: true);
      expect(shown(), isNull);
    });

    test(
      'a wallet read while a request runs is not taken and overtakes it',
      () {
        known.enterPaid(account, 'a', firstAttempt: true);
        wallet(42);
        expect(shown(), isNull);
        known.reportAnswer(account, 'a', 37);
        expect(shown(), isNull);
      },
    );

    test('an answer to a first attempt with nothing since sets it', () {
      wallet(42);
      known.enterPaid(account, 'a', firstAttempt: true);
      known.release('a'); // its execution completed
      known.reportAnswer(account, 'a', 37);
      expect(shown(), 37);
    });

    test(
      'an answer after a wallet change since its first attempt does not',
      () {
        known.enterPaid(account, 'a', firstAttempt: true);
        known.walletChanged();
        known.reportAnswer(account, 'a', 37);
        expect(shown(), isNull);
      },
    );

    test(
      'a retry after a purchase and a wallet read keeps the first mark: no figure',
      () {
        known.enterPaid(account, 'a', firstAttempt: true);
        known.forget(account, 'a'); // left or timed out without an answer
        known.walletChanged(); // bought credits on Plans
        wallet(120); // Plans read the wallet
        expect(shown(), 120);
        known.enterPaid(account, 'a', firstAttempt: false); // retry/recovery
        known.reportAnswer(account, 'a', 20); // the cached reply
        expect(shown(), isNull);
      },
    );

    test('a retry after only its own uncertain failure sets it', () {
      known.enterPaid(account, 'a', firstAttempt: true);
      known.forget(account, 'a');
      known.enterPaid(account, 'a', firstAttempt: false);
      known.reportAnswer(account, 'a', 37);
      expect(shown(), 37);
    });

    test('a request recovered from an earlier run never sets it', () {
      known.enterPaid(account, 'earlier-run', firstAttempt: false);
      known.reportAnswer(account, 'earlier-run', 20);
      expect(shown(), isNull);
    });

    test('a request on the other surface between attempts overtakes it', () {
      known.enterPaid(account, 'a', firstAttempt: true);
      known.forget(account, 'a');
      known.enterPaid(account, 'b', firstAttempt: true);
      known.reportAnswer(account, 'b', 40);
      expect(shown(), 40);
      known.enterPaid(account, 'a', firstAttempt: false);
      known.reportAnswer(account, 'a', 45);
      expect(shown(), isNull);
    });

    test('overlapping requests set nothing; the next one alone does', () {
      known.enterPaid(account, 'chat', firstAttempt: true);
      known.enterPaid(account, 'choose-a-step', firstAttempt: true);
      known.reportAnswer(account, 'choose-a-step', 45);
      expect(shown(), isNull);
      known.reportAnswer(account, 'chat', 40);
      expect(shown(), isNull);
      known.enterPaid(account, 'next', firstAttempt: true);
      known.reportAnswer(account, 'next', 35);
      expect(shown(), 35);
    });

    test(
      'a released request stops blocking later answers but overtakes earlier marks',
      () {
        known.enterPaid(account, 'old', firstAttempt: true);
        known.enterPaid(account, 'waiting', firstAttempt: true);
        // "old" is abandoned (Start another request) or its execution ends
        // with nobody waiting.
        known.release('old');
        known.reportAnswer(account, 'waiting', 30);
        expect(shown(), isNull, reason: 'old may have been charged after');
        known.enterPaid(account, 'new', firstAttempt: true);
        known.reportAnswer(account, 'new', 25);
        expect(shown(), 25);
        // A late completion of the abandoned request changes nothing.
        known.release('old');
        expect(shown(), 25);
      },
    );

    test('a failure without a figure forgets it', () {
      wallet(42);
      known.enterPaid(account, 'a', firstAttempt: true);
      known.forget(account, 'a');
      expect(shown(), isNull);
    });

    test('a wallet change forgets it', () {
      wallet(42);
      known.walletChanged();
      expect(shown(), isNull);
    });

    test('events for another account are ignored', () {
      wallet(42);
      known.enterPaid('someone-else', 'x', firstAttempt: true);
      known.forget('someone-else', 'x');
      known.reportAnswer('someone-else', 'x', 1);
      expect(shown(), 42);
    });
  });

  testWidgets(
    'after a timeout, Start another request lets the new answer set the balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // The first paid request never answers.
      final never = Completer<_Response>();
      final server = _Server(paidScript: [never.future]);
      final container = _setup(
        server,
        InMemorySecureStoreBackend(),
        paidWaitTimeout: const Duration(seconds: 2),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(find.textContaining('took too long'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Start another request', skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text('Start another request'));
      await _settle(tester);
      await tester.tap(find.text('Start new request'));
      await _settle(tester);

      await _ask(tester, 'And something else?', 'en');
      expect(server.paid, hasLength(2));
      expect(_balanceText(tester), 'Your balance: 20 credits');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a purchase or entitlement refresh elsewhere hides the Chat balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = _setup(_Server(), InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      expect(_balanceText(tester), 'Your balance: 20 credits');
      // What entitlement refreshes, restores and purchase completions call
      // next to invalidating the wallet (the entitlement refresh itself is
      // covered in entitlement_provider_test.dart).
      container.read(aiCreditKnownBalanceProvider.notifier).walletChanged();
      await tester.pump();
      expect(_balanceText(tester), isNull);
      // The reply's own historical figure stays.
      expect(_receipts(tester).single, contains('20 left after this reply'));
      expect(tester.takeException(), isNull);
    },
  );

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
        // A purchase may follow: the figure from before it is not kept.
        expect(container.read(aiCreditKnownBalanceProvider), isNull);
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
        // The mode switch is above it, so scroll down to the balance.
        await tester.scrollUntilVisible(
          balance,
          100,
          scrollable: find.byType(Scrollable).first,
        );
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

  testWidgets(
    'a reply this device withholds says its credits were used and what is left',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Only a claim the assistant cannot make, so nothing is left to show.
      final server = _Server(message: 'I have scheduled your Grocery list.');
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      expect(server.paid, hasLength(1));
      expect(find.textContaining('I have scheduled'), findsNothing);
      final message = _errorText(tester);
      expect(message, contains('did not pass the response check'));
      expect(message, contains('This message used its credits.'));
      expect(message, contains('Credits left: 20.'));
      expect(message, isNot(contains('charged')));
      expect(_balanceText(tester), 'Your balance: 20 credits');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'after a paid-step failure with no figure the balance is hidden and the message asks to check it',
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
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      expect(_balanceText(tester), 'Your balance: 20 credits');
      server.paidScript.add((
        status: 500,
        data: <String, dynamic>{'error': 'credit_settlement_failed'},
      ));
      await _ask(tester, 'And after that?', 'en');
      expect(server.paid, hasLength(2));
      expect(_balanceText(tester), isNull);
      final message = _errorText(tester);
      expect(message, contains('it may have used credits'));
      expect(message, contains('Check your balance before asking again.'));
      expect(message, isNot(contains('nothing was charged')));
      expect(message, isNot(contains('You can try again')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es']) {
    final es = language == 'es';
    testWidgets(
      '$language: Retry same request after the price expired does not say nothing was charged',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final server = _Server(
          paidScript: [
            // The first attempt reached the server, then the connection
            // dropped before its answer.
            StateError('connection dropped'),
            // By the retry the signed price had expired.
            (
              status: 409,
              data: <String, dynamic>{'error': 'credit_quote_required'},
            ),
          ],
        );
        final container = _setup(server, InMemorySecureStoreBackend());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await _ask(tester, 'When should I do the Grocery list?', language);
        final retry = find.text(
          es ? 'Reintentar la misma solicitud' : 'Retry same request',
        );
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await _settle(tester);
        expect(server.paid, hasLength(2));
        expect(
          server.paid.map((body) => body['requestId']).toSet(),
          hasLength(1),
        );
        final message = _errorText(tester);
        for (final claim
            in es
                ? ['No se cobraron', 'no se cobró', 'No se cobró']
                : [
                    'No credits were charged',
                    'nothing was charged',
                    'Nothing was charged',
                  ]) {
          expect(message, isNot(contains(claim)));
        }
        expect(
          message,
          contains(
            es
                ? 'es posible que haya usado créditos. Revisa tu saldo antes de volver a preguntar.'
                : 'it may have used credits. Check your balance before asking again.',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a sign-in refusal on Retry same request does not say nothing was charged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final server = _Server(
        paidScript: [
          StateError('connection dropped'),
          (status: 401, data: <String, dynamic>{'error': 'unauthorized'}),
        ],
      );
      final container = _setup(server, InMemorySecureStoreBackend());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      await tester.ensureVisible(find.text('Retry same request'));
      await tester.tap(find.text('Retry same request'));
      await _settle(tester);
      final message = _errorText(tester);
      expect(message, startsWith('Your sign-in needs renewing'));
      expect(message, isNot(contains('Nothing was charged')));
      expect(message, contains('may have used credits'));
      expect(tester.takeException(), isNull);
    },
  );

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
