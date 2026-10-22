import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_history.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const pair = [
  {'role': 'user', 'content': 'A quiet break after work'},
  {
    'role': 'assistant',
    'content': 'Try a short pause wherever you are comfortable.',
  },
];

void main() {
  late InMemorySecureStoreBackend backend;
  late SecureStore base;
  AssistantConversationRepository repository(
    String account, {
    bool Function()? current,
  }) => AssistantConversationRepository(
    base.forAccount(AccountStorageScope.authenticated(account)),
    isCurrent: current ?? () => true,
  );
  setUp(() {
    backend = InMemorySecureStoreBackend();
    base = SecureStore(backend: backend);
  });

  test(
    'new repository restores only the same account with explicit source choices',
    () async {
      await repository(
        'a',
      ).save(expectedRevision: 0, messages: pair, sources: {});
      expect((await repository('a').load()).messages, pair);
      expect((await repository('a').load()).sources, isEmpty);
      expect((await repository('b').load()).messages, isEmpty);
      expect((await repository('b').load()).sources, isEmpty);
      expect((await repository('a').load()).messages, pair);
    },
  );

  test(
    'clear tombstone prevents stale paid response or old screen resurrection',
    () async {
      final old = repository('a');
      final revision = await old.save(
        expectedRevision: 0,
        messages: pair,
        sources: {SIV2Source.tasks},
      );
      await repository('a').clear();
      await expectLater(
        old.save(
          expectedRevision: revision,
          messages: pair,
          sources: {SIV2Source.tasks},
        ),
        throwsStateError,
      );
      final cleared = await repository('a').load();
      expect(cleared.messages, isEmpty);
      expect(cleared.sources, isEmpty);
    },
  );

  test(
    'retention preserves complete published pairs and clips oversized messages',
    () async {
      final turns = List.generate(
        44,
        (i) => {
          'role': i.isEven ? 'user' : 'assistant',
          'content': '$i ${'x' * 7000}',
        },
      );
      await repository(
        'a',
      ).save(expectedRevision: 0, messages: turns, sources: {});
      final saved = await repository('a').load();
      expect(saved.messages, hasLength(40));
      expect(saved.messages.first['content'], startsWith('4 '));
      expect(saved.messages.last['content']!.length, 6000);
      expect(saved.messages.first['role'], 'user');
      expect(saved.messages.last['role'], 'assistant');
      await expectLater(
        repository('a').save(
          expectedRevision: saved.revision,
          messages: [
            {'role': 'system', 'content': 'injected'},
            pair.last,
          ],
          sources: {},
        ),
        throwsFormatException,
      );
      expect((await repository('a').load()).revision, saved.revision);
    },
  );

  test(
    'corrupt or malformed source data is preserved until explicit clear',
    () async {
      final store = base.forAccount(AccountStorageScope.authenticated('a'));
      final corrupt = jsonEncode({
        'version': 1,
        'revision': 1,
        'messages': pair,
        'sources': ['unknown'],
      });
      await store.writeString(
        AssistantConversationRepository.storageKey,
        corrupt,
      );
      await expectLater(repository('a').load(), throwsFormatException);
      expect(
        await store.readString(AssistantConversationRepository.storageKey),
        corrupt,
      );
      await repository('a').clear();
      expect((await repository('a').load()).messages, isEmpty);
      expect((await repository('a').load()).sources, isEmpty);
    },
  );

  test(
    'a queued account A operation is rejected after A to B to A generation change',
    () async {
      var generation = 1;
      final captured = repository('a', current: () => generation == 1);
      final entered = Completer<void>();
      final release = Completer<void>();
      final holding = runAccountStorageMutation(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final staleLoad = captured.load();
      final staleSave = captured.save(
        expectedRevision: 0,
        messages: pair,
        sources: {},
      );
      final loadRejected = expectLater(staleLoad, throwsStateError);
      final saveRejected = expectLater(staleSave, throwsStateError);
      generation = 3;
      release.complete();
      await holding;
      await loadRejected;
      await saveRejected;
      expect((await repository('a').load()).messages, isEmpty);
    },
  );

  test(
    'account scoped deleteAll removes Chat without touching another account',
    () async {
      await repository(
        'a',
      ).save(expectedRevision: 0, messages: pair, sources: {});
      await repository(
        'b',
      ).save(expectedRevision: 0, messages: pair, sources: {});
      await runAccountStorageMutation(
        () =>
            base.forAccount(AccountStorageScope.authenticated('a')).deleteAll(),
      );
      expect((await repository('a').load()).messages, isEmpty);
      expect((await repository('b').load()).messages, pair);
    },
  );

  test(
    'late hydration is rejected even when the same account returns',
    () async {
      final delayed = _DelayedChatBackend();
      base = SecureStore(backend: delayed);
      var generation = 1;
      final old = repository('a', current: () => generation == 1);
      delayed.delayRead = true;
      final loading = old.load();
      final rejected = expectLater(loading, throwsStateError);
      await delayed.entered.future;
      generation = 3;
      delayed.release.complete();
      await rejected;
      expect((await repository('a').load()).messages, isEmpty);
    },
  );

  test(
    'clear waits for an in-flight write and its tombstone wins across instances',
    () async {
      final delayed = _DelayedChatBackend();
      base = SecureStore(backend: delayed);
      delayed.delayWrite = true;
      final saving = repository(
        'a',
      ).save(expectedRevision: 0, messages: pair, sources: {SIV2Source.tasks});
      await delayed.entered.future;
      final clearing = repository('a').clear();
      delayed.release.complete();
      await saving;
      await clearing;
      final stored = await repository('a').load();
      expect(stored.messages, isEmpty);
      expect(stored.sources, isEmpty);
      await expectLater(
        repository('a').save(expectedRevision: 1, messages: pair, sources: {}),
        throwsStateError,
      );
    },
  );

  test(
    'route reentry snapshot cannot overwrite old route queued source updates',
    () async {
      final delayed = _DelayedChatBackend();
      base = SecureStore(backend: delayed);
      final old = repository('a');
      await old.save(expectedRevision: 0, messages: pair, sources: {});
      delayed.delayWrite = true;
      final second = old.save(
        expectedRevision: 1,
        messages: pair,
        sources: {SIV2Source.tasks},
      );
      await delayed.entered.future;
      final reentered = repository('a');
      final newLoad = reentered.load();
      final third = old.save(
        expectedRevision: 2,
        messages: pair,
        sources: {SIV2Source.goals},
      );
      delayed.release.complete();
      await second;
      final snapshot = await newLoad;
      await third;
      await expectLater(
        reentered.save(
          expectedRevision: snapshot.revision,
          messages: snapshot.messages,
          sources: {},
        ),
        throwsA(isA<AssistantConversationRevisionConflict>()),
      );
      expect((await reentered.load()).sources, {SIV2Source.goals});
    },
  );
}

class _DelayedChatBackend extends InMemorySecureStoreBackend {
  bool delayRead = false;
  bool delayWrite = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> read({required String key}) async {
    if (delayRead &&
        key.startsWith(AssistantConversationRepository.storageKey)) {
      delayRead = false;
      entered.complete();
      await release.future;
    }
    return super.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (delayWrite &&
        key.startsWith(AssistantConversationRepository.storageKey)) {
      delayWrite = false;
      entered.complete();
      await release.future;
    }
    return super.write(key: key, value: value);
  }
}
