import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
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
    'account scoped deleteAll also removes a pending paid request',
    () async {
      await repository(
        'a',
      ).savePending(pendingFor(ConversationSurface.si, 'chat-request'));
      await runAccountStorageMutation(
        () =>
            base.forAccount(AccountStorageScope.authenticated('a')).deleteAll(),
      );
      expect((await repository('a').load()).pendingRequests, isEmpty);
    },
  );

  test(
    'Choose a step requests are stored and read when the Chat part is damaged, without rewriting it',
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
      await repository(
        'a',
      ).savePending(pendingFor(ConversationSurface.planner, 'plan-request'));
      await expectLater(repository('a').load(), throwsFormatException);
      final pendingOnly = await repository('a').loadPending();
      expect(
        pendingOnly.pendingRequests[ConversationSurface.planner]!.requestId,
        'plan-request',
      );
      final stored =
          jsonDecode(
                (await store.readString(
                  AssistantConversationRepository.storageKey,
                ))!,
              )
              as Map<String, dynamic>;
      expect({...stored}..remove('pendingRequests'), jsonDecode(corrupt));
      await repository(
        'a',
      ).clearPending(ConversationSurface.planner, requestId: 'plan-request');
      expect(
        await store.readString(AssistantConversationRepository.storageKey),
        corrupt,
      );
    },
  );

  test(
    'requests past their collect-by time keep no content once purged, but are still reported',
    () async {
      final old = DateTime.now().subtract(const Duration(minutes: 10));
      await repository(
        'a',
      ).save(expectedRevision: 0, messages: pair, sources: {});
      await repository('a').savePending(
        pendingFor(ConversationSurface.si, 'old-chat', savedAt: old),
      );
      await repository(
        'a',
      ).savePending(pendingFor(ConversationSurface.planner, 'live-plan'));
      final store = base.forAccount(AccountStorageScope.authenticated('a'));
      Future<String> raw() async =>
          (await store.readString(AssistantConversationRepository.storageKey))!;

      // A request still running in the app is left alone.
      await repository('a').load(keep: (id) => id == 'old-chat');
      expect(await raw(), contains('old-chat'));
      expect(
        RegExp('Compare my two options').allMatches(await raw()).length,
        2,
      );

      // Loading reports the expired request with its content once, so the
      // screen can restore the question, and leaves only a marker behind.
      final loaded = await repository('a').load();
      expect(
        loaded.pendingRequests[ConversationSurface.si]!.requestId,
        'old-chat',
      );
      expect(loaded.messages, pair);
      final purged = await raw();
      expect(
        RegExp('Compare my two options').allMatches(purged).length,
        1,
        reason: 'Only the live Choose a step request keeps its content.',
      );
      final reloaded = await repository('a').load();
      expect(reloaded.pendingRequests.keys, [ConversationSurface.planner]);
      expect(reloaded.expiredPendingRequests, {
        ConversationSurface.si: 'old-chat',
      });
      expect(reloaded.revision, loaded.revision);

      // Account readiness purges without any screen, and is idempotent.
      await repository('b').savePending(
        pendingFor(ConversationSurface.planner, 'b-old', savedAt: old),
      );
      expect(await repository('b').purgeExpiredPending(), isNull);
      expect(await repository('b').purgeExpiredPending(), isNull);
      final b = await repository('b').loadPending();
      expect(b.pendingRequests, isEmpty);
      expect(b.expiredPendingRequests, {ConversationSurface.planner: 'b-old'});

      // A new request on that surface reports the untold marker it replaces,
      // and the purge returns its collect-by time for the in-app timer.
      final fresh = pendingFor(ConversationSurface.planner, 'b-new');
      expect(await repository('b').savePending(fresh), isTrue);
      expect(await repository('b').savePending(fresh), isFalse);
      expect(await repository('b').purgeExpiredPending(), fresh.collectBefore);

      // Telling the person removes the marker.
      await repository(
        'a',
      ).clearPending(ConversationSurface.si, requestId: 'old-chat');
      expect((await repository('a').load()).expiredPendingRequests, isEmpty);
    },
  );

  test(
    'an unreadable stored request is reduced to a content-free marker',
    () async {
      final store = base.forAccount(AccountStorageScope.authenticated('a'));
      await store.writeString(
        AssistantConversationRepository.storageKey,
        jsonEncode({
          'version': 1,
          'revision': 0,
          'messages': <Object?>[],
          'sources': <Object?>[],
          'pendingRequests': {
            'planner': {'body': 'private words', 'requestId': 7},
          },
        }),
      );
      await repository('a').purgeExpiredPending();
      final raw = await store.readString(
        AssistantConversationRepository.storageKey,
      );
      expect(raw, isNot(contains('private words')));
      expect((await repository('a').loadPending()).unreadablePendingRequests, {
        ConversationSurface.planner,
      });
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

  test('Chat saved before pending requests existed still loads', () async {
    final store = base.forAccount(AccountStorageScope.authenticated('a'));
    await store.writeString(
      AssistantConversationRepository.storageKey,
      jsonEncode({
        'version': 1,
        'revision': 3,
        'messages': pair,
        'sources': ['tasks'],
      }),
    );
    final saved = await repository('a').load();
    expect(saved.revision, 3);
    expect(saved.messages, pair);
    expect(saved.sources, {SIV2Source.tasks});
    expect(saved.pendingRequests, isEmpty);
    expect(saved.unreadablePendingRequests, isEmpty);
  });

  test(
    'a pending request round-trips byte for byte per surface without changing the Chat revision',
    () async {
      final revision = await repository(
        'a',
      ).save(expectedRevision: 0, messages: pair, sources: {});
      final chat = pendingFor(ConversationSurface.si, 'chat-request');
      final planner = pendingFor(ConversationSurface.planner, 'plan-request');
      await repository('a').savePending(chat);
      await repository('a').savePending(planner);
      final loaded = await repository('a').load();
      expect(loaded.revision, revision);
      expect(loaded.messages, pair);
      final restored = loaded.pendingRequests[ConversationSurface.si]!;
      expect(
        jsonEncode({
          ...restored.quote.packet.toJson(),
          'quote': restored.quote.data,
        }),
        jsonEncode({...chat.quote.packet.toJson(), 'quote': chat.quote.data}),
      );
      expect(
        loaded.pendingRequests[ConversationSurface.planner]!.requestId,
        'plan-request',
      );
      expect((await repository('b').load()).pendingRequests, isEmpty);

      // Another id never removes the stored request.
      await repository(
        'a',
      ).clearPending(ConversationSurface.si, requestId: 'other');
      expect((await repository('a').load()).pendingRequests, hasLength(2));

      // Publishing the reply removes the Chat request in the same write.
      final published = await repository('a').save(
        expectedRevision: revision,
        messages: [...pair, ...pair],
        sources: {},
        completedRequestId: 'chat-request',
      );
      final after = await repository('a').load();
      expect(after.revision, published);
      expect(after.pendingRequests.keys, [ConversationSurface.planner]);

      // Clearing Chat keeps a request still running on Choose a step.
      await repository('a').savePending(chat);
      await repository('a').clear();
      final cleared = await repository('a').load();
      expect(cleared.messages, isEmpty);
      expect(cleared.pendingRequests.keys, [ConversationSurface.planner]);
    },
  );

  test(
    'a damaged pending request is reported without hiding saved Chat',
    () async {
      final store = base.forAccount(AccountStorageScope.authenticated('a'));
      final valid = pendingFor(ConversationSurface.si, 'chat-request').toJson();
      await store.writeString(
        AssistantConversationRepository.storageKey,
        jsonEncode({
          'version': 1,
          'revision': 2,
          'messages': pair,
          'sources': <String>[],
          'pendingRequests': {
            'si': {...valid, 'body': '${valid['body']} '},
            'planner': 'not a request',
          },
        }),
      );
      final saved = await repository('a').load();
      expect(saved.messages, pair);
      expect(saved.pendingRequests, isEmpty);
      expect(saved.unreadablePendingRequests, {
        ConversationSurface.si,
        ConversationSurface.planner,
      });
      await repository(
        'a',
      ).clearPending(ConversationSurface.si, requestId: null);
      final after = await repository('a').load();
      expect(after.revision, 2);
      expect(after.unreadablePendingRequests, {ConversationSurface.planner});
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

  group('information scope choice', () {
    Future<void> writeRaw(String account, Map<String, Object?> envelope) => base
        .forAccount(AccountStorageScope.authenticated(account))
        .writeString(
          AssistantConversationRepository.storageKey,
          jsonEncode(envelope),
        );

    test(
      'a new account has made no choice and has not seen the explanation',
      () async {
        final fresh = await repository('a').load();
        expect(fresh.sourcesChosen, isFalse);
        expect(fresh.scopeExplained, isFalse);
      },
    );

    test(
      'older saved chats keep their selection as chosen, even an empty one',
      () async {
        await writeRaw('a', {
          'version': 1,
          'revision': 3,
          'messages': pair,
          'sources': <String>[],
        });
        await writeRaw('b', {
          'version': 1,
          'revision': 3,
          'messages': pair,
          'sources': ['goals'],
        });
        final a = await repository('a').load();
        expect(a.sourcesChosen, isTrue);
        expect(a.sources, isEmpty);
        expect(a.messages, pair);
        // Marking the explanation never turns an old choice into a default.
        await repository('a').markScopeExplained();
        expect((await repository('a').load()).sourcesChosen, isTrue);
        final b = await repository('b').load();
        expect(b.sourcesChosen, isTrue);
        expect(b.sources, {SIV2Source.goals});
      },
    );

    test('save records whether the selection was chosen', () async {
      final revision = await repository('a').save(
        expectedRevision: 0,
        messages: pair,
        sources: SIV2Source.values.toSet(),
        sourcesChosen: false,
      );
      expect((await repository('a').load()).sourcesChosen, isFalse);
      await repository('a').save(
        expectedRevision: revision,
        messages: pair,
        sources: {},
        sourcesChosen: true,
      );
      final chosen = await repository('a').load();
      expect(chosen.sourcesChosen, isTrue);
      expect(chosen.sources, isEmpty);
    });

    test('a malformed choice marker is reported, not guessed', () async {
      await writeRaw('a', {
        'version': 1,
        'revision': 1,
        'messages': pair,
        'sources': <String>[],
        'sourcesChosen': 'yes',
      });
      await expectLater(repository('a').load(), throwsFormatException);
    });

    test(
      'the explanation stays seen across saves and clear, never touching chat or a pending request',
      () async {
        final revision = await repository(
          'a',
        ).save(expectedRevision: 0, messages: pair, sources: {});
        await repository(
          'a',
        ).savePending(pendingFor(ConversationSurface.planner, 'planner-1'));
        await repository('a').markScopeExplained();
        final marked = await repository('a').load();
        expect(marked.scopeExplained, isTrue);
        expect(marked.revision, revision);
        expect(marked.messages, pair);
        expect(marked.sourcesChosen, isTrue);
        expect(
          marked.pendingRequests[ConversationSurface.planner]?.requestId,
          'planner-1',
        );
        await repository(
          'a',
        ).save(expectedRevision: revision, messages: pair, sources: {});
        expect((await repository('a').load()).scopeExplained, isTrue);
        await repository('a').clear();
        final cleared = await repository('a').load();
        expect(cleared.scopeExplained, isTrue);
        expect(cleared.sourcesChosen, isFalse);
        expect(cleared.messages, isEmpty);
        expect((await repository('b').load()).scopeExplained, isFalse);
      },
    );

    test(
      'marking the explanation on a new account keeps My plan and creates no chat',
      () async {
        await repository('a').markScopeExplained();
        final loaded = await repository('a').load();
        expect(loaded.scopeExplained, isTrue);
        expect(loaded.revision, 0);
        expect(loaded.messages, isEmpty);
        expect(loaded.sourcesChosen, isFalse);
      },
    );

    test(
      'a request stored on a new account by Choose a step keeps My plan',
      () async {
        await repository(
          'a',
        ).savePending(pendingFor(ConversationSurface.planner, 'planner-1'));
        final loaded = await repository('a').load();
        expect(loaded.sourcesChosen, isFalse);
        expect(
          loaded.pendingRequests[ConversationSurface.planner]?.requestId,
          'planner-1',
        );
      },
    );

    test(
      'a record an earlier build wrote only for a Choose a step request keeps My plan',
      () async {
        // Neither an earlier save nor an earlier Clear writes revision 0, so
        // this record holds no Chat choice: only the planner request.
        await writeRaw('a', {
          'version': 1,
          'revision': 0,
          'messages': <Object?>[],
          'sources': <String>[],
          'pendingRequests': {
            'planner': pendingFor(
              ConversationSurface.planner,
              'planner-1',
            ).toJson(),
          },
        });
        final loaded = await repository('a').load();
        expect(loaded.sourcesChosen, isFalse);
        expect(
          loaded.pendingRequests[ConversationSurface.planner]?.requestId,
          'planner-1',
        );
      },
    );
  });
}

PendingConversationRequest pendingFor(
  ConversationSurface surface,
  String requestId, {
  DateTime? savedAt,
}) => PendingConversationRequest(
  quote: ConversationQuote(
    packet: ConversationPacket(
      surface: surface,
      accountScope: 'account:a',
      prompt: 'Compare my two options.',
      history: pair,
      context: {'language': 'en'},
      requestId: requestId,
    ),
    data: {
      'credits': 4,
      'digest': 'd',
      'proof': 'p',
      'policy': 'v',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    },
  ),
  savedAt: savedAt ?? DateTime.now(),
);

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
