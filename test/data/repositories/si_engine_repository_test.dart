import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
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
