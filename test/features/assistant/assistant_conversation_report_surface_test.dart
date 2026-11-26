import 'dart:async';

import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  _Server({required this.message});

  final String message;
  final paid = <Map<String, dynamic>>[];

  Future<_Response> call(Map<String, dynamic> body) async {
    if (body['quoteOnly'] == true) return (status: 200, data: _quote(body));
    paid.add(body);
    return (
      status: 200,
      data: <String, dynamic>{
        'requestId': body['requestId'],
        'message': message,
        'creditsCharged': conversationMessageCredits,
        'remainingCredits': 20,
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
  Stream<SubscriptionState>? purchaseOutcomes,
  List<Override> extraOverrides = const [],
}) => ProviderContainer(
  overrides: [
    if (purchaseOutcomes != null)
      paywallPurchaseOutcomeProvider.overrideWith((ref) => purchaseOutcomes),
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
    ...extraOverrides,
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  double textScale = 1,
  ConversationSurface surface = ConversationSurface.si,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            AssistantConversationScreen(surface: surface, onLocalTools: () {}),
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

// A reported reply carries the screen it came from: the Planner's AI chat
// reports as `planner`, the Chat screen as `chat`.

class _RecordingReports extends AiContentReportActions {
  _RecordingReports(super.ref, this.sent);

  final List<({String text, String surface})> sent;

  @override
  Future<void> submit({
    required String responseText,
    required AiContentReportReason reason,
    required String surface,
  }) async {
    sent.add((text: responseText, surface: surface));
  }
}

void main() {
  for (final entry in {
    ConversationSurface.planner: 'planner',
    ConversationSurface.si: 'chat',
  }.entries) {
    testWidgets('a report from ${entry.key.name} is sent as ${entry.value}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sent = <({String text, String surface})>[];
      final server = _Server(message: 'A reply to report.');
      final container = _setup(
        server,
        InMemorySecureStoreBackend(),
        extraOverrides: [
          aiContentReportActionsProvider.overrideWith(
            (ref) => _RecordingReports(ref, sent),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container, surface: entry.key);
      await _ask(tester, 'When should I do the Grocery list?', 'en');
      final report = find.text('Report response');
      await tester.ensureVisible(report);
      await tester.tap(report);
      await _settle(tester);
      await tester.tap(find.text('Send report'));
      await _settle(tester);
      expect(sent, [(text: 'A reply to report.', surface: entry.value)]);
    });
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
