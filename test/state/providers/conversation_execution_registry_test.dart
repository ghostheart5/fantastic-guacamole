import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<_RecordedTimer> timers;
  late String account;
  late int generation;
  late InMemorySecureStoreBackend backend;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
      // A fresh scope object on every rebuild, as each auth event produces.
      accountStorageScopeProvider.overrideWith(
        (ref) => AccountStorageScope.authenticated(account),
      ),
      authSessionBoundaryProvider.overrideWith(
        () => _Boundary(() => generation),
      ),
      conversationPurgeTimerProvider.overrideWithValue((delay, callback) {
        final timer = _RecordedTimer(delay, callback);
        timers.add(timer);
        return timer;
      }),
    ],
  );

  PendingConversationRequest pending(
    ConversationSurface surface,
    String id, {
    required DateTime savedAt,
  }) => PendingConversationRequest(
    quote: ConversationQuote(
      packet: ConversationPacket(
        surface: surface,
        accountScope: AccountStorageScope.authenticated(account).v2Namespace!,
        prompt: 'Private question $id',
        history: const [],
        context: const {'language': 'en'},
        requestId: id,
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
    savedAt: savedAt,
  );

  Future<String> raw() async => (await SecureStore(backend: backend)
      .forAccount(AccountStorageScope.authenticated(account))
      .readString(AssistantConversationRepository.storageKey))!;

  setUp(() {
    timers = [];
    account = 'registry-a';
    generation = 1;
    backend = InMemorySecureStoreBackend();
  });

  test('an account or generation change cancels the purge timer', () {
    final c = container();
    addTearDown(c.dispose);
    final first = c.read(conversationExecutionRegistryProvider);
    first.schedulePurge(DateTime.now().add(const Duration(minutes: 5)));
    expect(timers.single.isActive, isTrue);

    account = 'registry-b';
    c.invalidate(accountStorageScopeProvider);
    expect(c.read(conversationExecutionRegistryProvider), isNot(first));
    expect(timers.single.isActive, isFalse);

    final second = c.read(conversationExecutionRegistryProvider);
    second.schedulePurge(DateTime.now().add(const Duration(minutes: 5)));
    expect(timers.last.isActive, isTrue);
    generation = 2;
    c.invalidate(authSessionBoundaryProvider);
    expect(c.read(conversationExecutionRegistryProvider), isNot(second));
    expect(timers.last.isActive, isFalse);

    // A rebuilt scope for the same account keeps the registry and timer.
    final third = c.read(conversationExecutionRegistryProvider);
    third.schedulePurge(DateTime.now().add(const Duration(minutes: 5)));
    c.invalidate(accountStorageScopeProvider);
    expect(c.read(conversationExecutionRegistryProvider), same(third));
    expect(timers.last.isActive, isTrue);
  });

  test(
    'two surfaces with different deadlines: the earlier purges, then the timer re-arms for the later one',
    () async {
      final c = container();
      addTearDown(c.dispose);
      final now = DateTime.now();
      final repository = c.read(
        assistantConversationHistoryRepositoryProvider,
      )!;
      await repository.savePending(
        pending(
          ConversationSurface.si,
          'chat-old',
          savedAt: now.subtract(const Duration(minutes: 10)),
        ),
      );
      final later = pending(
        ConversationSurface.planner,
        'plan-live',
        savedAt: now,
      );
      await repository.savePending(later);

      final registry = c.read(conversationExecutionRegistryProvider);
      registry.schedulePurge(now);
      // A same-account auth event replaces the repository before firing.
      c.invalidate(accountStorageScopeProvider);
      expect(
        c.read(assistantConversationHistoryRepositoryProvider),
        isNot(same(repository)),
      );

      timers.single.callback();
      await pumpEventQueue();

      final stored = await raw();
      expect(stored, isNot(contains('Private question chat-old')));
      expect(stored, contains('Private question plan-live'));
      expect(timers, hasLength(2));
      expect(timers.last.isActive, isTrue);
      expect(
        timers.last.delay,
        greaterThan(
          later.collectBefore.difference(DateTime.now()) -
              const Duration(seconds: 5),
        ),
      );
    },
  );
}

final class _RecordedTimer implements Timer {
  _RecordedTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool _cancelled = false;

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

class _Boundary extends AuthSessionBoundaryNotifier {
  _Boundary(this._generation);
  final int Function() _generation;

  @override
  AuthSessionBoundary build() => AuthSessionBoundary(
    generation: _generation(),
    userId: 'registry-user',
    isTransitioning: false,
    isStorageReady: true,
  );
}
