import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStoreBackend backend;
  late SiEngineRepository repository;

  setUp(() {
    backend = InMemorySecureStoreBackend();
    repository = SiEngineRepository(
      SecureStore(backend: backend),
      AccountStorageScope.authenticated('user-1'),
    );
  });

  test('returns null when persisted SI engine state is corrupt', () async {
    await SecureStore(backend: backend).writeString(
      repository.stateKey(AssistantConversationScope.primarySiConsole)!,
      '{not-json',
    );

    final Map<String, dynamic>? state = await Logger.withMutedErrors(
      () => repository.loadState(AssistantConversationScope.primarySiConsole),
    );

    expect(state, isNull);
  });

  test('loads dynamic map state using string keys', () async {
    await repository.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{'mode': 'adaptive', 'score': 7},
    );

    final Map<String, dynamic>? state = await repository.loadState(
      AssistantConversationScope.primarySiConsole,
    );

    expect(state, isNotNull);
    expect(state?['mode'], 'adaptive');
    expect(state?['score'], 7);
  });

  test('returns null for non-map payload types', () async {
    await SecureStore(backend: backend).writeString(
      repository.stateKey(AssistantConversationScope.primarySiConsole)!,
      jsonEncode(<String>['bad']),
    );

    final state = await repository.loadState(
      AssistantConversationScope.primarySiConsole,
    );

    expect(state, isNull);
  });

  test('exports a copy and clears only SI engine state', () async {
    await repository.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{
        'memoryEvents': <String>['a'],
      },
    );

    final Map<String, dynamic>? exported = await repository.exportState(
      AssistantConversationScope.primarySiConsole,
    );
    exported?['changed'] = true;
    expect(
      (await repository.loadState(
        AssistantConversationScope.primarySiConsole,
      ))?['changed'],
      isNull,
    );

    await repository.clearState(AssistantConversationScope.primarySiConsole);
    expect(
      await repository.loadState(AssistantConversationScope.primarySiConsole),
      isNull,
    );
  });

  test('reloads a complete validated assistant evidence exchange', () async {
    final AssistantEvidenceExchange exchange = _exchange(
      accountScopeId: repository.accountScopeId!,
    );
    await repository.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{'assistantEvidenceExchange': exchange.toJson()},
    );

    final AssistantEvidenceExchange? loaded = await repository
        .loadAssistantEvidenceExchange(
          AssistantConversationScope.primarySiConsole,
        );

    expect(loaded, isNotNull);
    expect(loaded!.request.requestId, exchange.request.requestId);
    expect(loaded.response.message, exchange.response.message);
    expect(loaded.manifest.snapshotVersion, exchange.manifest.snapshotVersion);
    loaded.validate();
  });

  test('persisted evidence exchange fails closed after tampering', () async {
    final AssistantEvidenceExchange exchange = _exchange(
      accountScopeId: repository.accountScopeId!,
    );
    final Map<String, dynamic> tampered =
        jsonDecode(jsonEncode(exchange.toJson()))! as Map<String, dynamic>;
    (tampered['response']! as Map<String, dynamic>)['message'] =
        'Forged persisted response';
    await repository.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{'assistantEvidenceExchange': tampered},
    );

    final AssistantEvidenceExchange? loaded = await Logger.withMutedErrors(
      () => repository.loadAssistantEvidenceExchange(
        AssistantConversationScope.primarySiConsole,
      ),
    );

    expect(loaded, isNull);
  });

  test('persisted evidence exchange cannot cross account scope', () async {
    final AssistantEvidenceExchange wrongOwner = _exchange(
      accountScopeId: AccountStorageScope.authenticated(
        'different-user',
      ).v2Namespace!,
    );
    await repository.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{'assistantEvidenceExchange': wrongOwner.toJson()},
    );

    final AssistantEvidenceExchange? loaded = await Logger.withMutedErrors(
      () => repository.loadAssistantEvidenceExchange(
        AssistantConversationScope.primarySiConsole,
      ),
    );

    expect(loaded, isNull);
  });

  test('isolates state by account, surface, and conversation', () async {
    final SecureStore store = SecureStore(backend: backend);
    final SiEngineRepository accountA = SiEngineRepository(
      store,
      AccountStorageScope.authenticated('account-a'),
    );
    final SiEngineRepository accountB = SiEngineRepository(
      store,
      AccountStorageScope.authenticated('account-b'),
    );
    const AssistantConversationScope plannerPrimary =
        AssistantConversationScope.primarySmartPlanner;
    const AssistantConversationScope plannerSecondary =
        AssistantConversationScope(
          surface: AssistantSurface.smartPlanner,
          conversationId: 'secondary',
        );
    const AssistantConversationScope consolePrimary =
        AssistantConversationScope.primarySiConsole;

    await accountA.saveState(plannerPrimary, <String, dynamic>{
      'message': 'planner-a-primary',
    });
    await accountA.saveState(plannerSecondary, <String, dynamic>{
      'message': 'planner-a-secondary',
    });
    await accountA.saveState(consolePrimary, <String, dynamic>{
      'message': 'console-a-primary',
    });
    await accountB.saveState(consolePrimary, <String, dynamic>{
      'message': 'console-b-primary',
    });

    expect(
      (await accountA.loadState(plannerPrimary))?['message'],
      'planner-a-primary',
    );
    expect(
      (await accountA.loadState(plannerSecondary))?['message'],
      'planner-a-secondary',
    );
    expect(
      (await accountA.loadState(consolePrimary))?['message'],
      'console-a-primary',
    );
    expect(
      (await accountB.loadState(consolePrimary))?['message'],
      'console-b-primary',
    );
    expect(<String?>{
      accountA.stateKey(plannerPrimary),
      accountA.stateKey(plannerSecondary),
      accountA.stateKey(consolePrimary),
      accountB.stateKey(consolePrimary),
    }, hasLength(4));
  });

  test('fails closed outside an authenticated account scope', () async {
    final SecureStore store = SecureStore(backend: backend);
    final SiEngineRepository signedOut = SiEngineRepository(
      store,
      const AccountStorageScope.signedOut(),
    );

    await signedOut.saveState(
      AssistantConversationScope.primarySiConsole,
      <String, dynamic>{'message': 'must-not-persist'},
    );

    expect(
      signedOut.stateKey(AssistantConversationScope.primarySiConsole),
      isNull,
    );
    expect(
      await signedOut.loadState(AssistantConversationScope.primarySiConsole),
      isNull,
    );
  });

  test('does not adopt ambiguous legacy global state', () async {
    final SecureStore store = SecureStore(backend: backend);
    await store.writeString(
      'si_engine_state_v1',
      jsonEncode(<String, dynamic>{'message': 'legacy-global'}),
    );

    expect(
      await repository.loadState(AssistantConversationScope.primarySiConsole),
      isNull,
    );
    expect(await store.readString('si_engine_state_v1'), isNotNull);

    await repository.clearLegacyState();
    expect(await store.readString('si_engine_state_v1'), isNull);
  });
}

AssistantEvidenceExchange _exchange({required String accountScopeId}) {
  final DateTime now = DateTime.utc(2026, 8, 20, 18);
  const AssistantConversationScope conversation =
      AssistantConversationScope.primarySiConsole;
  final AssistantRequestEnvelope request = createAssistantRequestEnvelope(
    accountScopeId: accountScopeId,
    conversation: conversation,
    kind: AssistantRequestKind.consoleQuery,
    input: 'What needs attention?',
    now: now,
    requestId: 'persisted-evidence-request',
  );
  final AssistantEvidenceBundle evidence = AssistantEvidenceBundle(
    requestId: request.requestId,
    conversation: conversation,
    collectedAt: now,
    items: <AssistantEvidenceItem>[
      AssistantEvidenceItem(
        evidenceId: 'persisted-task-fact',
        kind: AssistantEvidenceKind.domainFact,
        sourceId: 'tasks',
        summary: 'One current task needs attention.',
        observedAt: now,
        freshness: AssistantEvidenceFreshness.current,
      ),
    ],
  );
  final AssistantResponseEnvelope response = AssistantResponseEnvelope(
    responseId: 'persisted-evidence-response',
    requestId: request.requestId,
    accountScopeId: request.accountScopeId,
    conversation: conversation,
    status: AssistantResponseStatus.completed,
    message: 'Review the current task.',
    processingMode: AssistantContractProcessingMode.onDevice,
    generatedAt: now,
    evidence: evidence,
  );
  return AssistantEvidenceExchange(
    request: request,
    response: response,
    manifest: createAssistantEvidenceManifest(
      request: request,
      evidence: evidence,
      responseMessage: response.message,
      createdAt: now,
    ),
  );
}
