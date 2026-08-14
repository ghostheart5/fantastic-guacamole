import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_TestScopeController, AccountStorageScope>
_scopeProvider = NotifierProvider<_TestScopeController, AccountStorageScope>(
  _TestScopeController.new,
);

final Provider<LearningState> _directLearningInputProvider =
    Provider<LearningState>((Ref ref) => ref.watch(learningProvider));

void main() {
  test(
    'Learning V2 storage isolates A and B with identical field ids',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final ProviderContainer container = _container(
        SecureStore(backend: backend),
      );
      addTearDown(container.dispose);

      await _setScope(container, AccountStorageScope.authenticated('a/b'));
      await container
          .read(learningProvider.notifier)
          .apply(
            const LearningState(
              completed: 11,
              taskAffinity: <String, double>{'same': .2},
            ),
          );

      await _setScope(container, AccountStorageScope.authenticated('a?b'));
      expect(container.read(learningProvider).completed, 0);
      await container
          .read(learningProvider.notifier)
          .apply(
            const LearningState(
              completed: 29,
              taskAffinity: <String, double>{'same': .9},
            ),
          );

      await _setScope(container, AccountStorageScope.authenticated('a/b'));
      expect(container.read(learningProvider).completed, 11);
      expect(container.read(learningProvider).taskAffinity['same'], .2);

      await _setScope(container, AccountStorageScope.authenticated('a?b'));
      expect(container.read(learningProvider).completed, 29);
      expect(container.read(learningProvider).taskAffinity['same'], .9);
    },
  );

  test(
    'global and sanitized Learning legacy values remain inactive and preserved',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      await store.writeString('ai_learning', '{"completed":91}');
      await store.writeString('ai_learning.a_b', '{"completed":92}');
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);

      await _setScope(container, AccountStorageScope.authenticated('a/b'));
      expect(container.read(learningProvider).completed, 0);
      await _setScope(container, AccountStorageScope.authenticated('a?b'));
      expect(container.read(learningProvider).completed, 0);

      expect(await store.readString('ai_learning'), '{"completed":91}');
      expect(await store.readString('ai_learning.a_b'), '{"completed":92}');
    },
  );

  test(
    'restart and signed-out transition retain only the owning V2 Learning',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      final ProviderContainer first = _container(store);
      await _setScope(first, AccountStorageScope.authenticated('A'));
      await first
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 7));
      await _setScope(first, const AccountStorageScope.signedOut());
      first.dispose();

      final ProviderContainer second = _container(store);
      addTearDown(second.dispose);
      await _setScope(second, AccountStorageScope.authenticated('B'));
      expect(second.read(learningProvider).completed, 0);

      final ProviderContainer restoredA = _container(store);
      addTearDown(restoredA.dispose);
      await _setScope(restoredA, AccountStorageScope.authenticated('A'));
      expect(restoredA.read(learningProvider).completed, 7);
    },
  );

  test(
    'same-user refresh retains V2 Learning without legacy migration',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      await store.writeString('ai_learning.same', '{"completed":99}');
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'same',
      );

      await _setScope(container, scope);
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 8));
      await _setScope(container, scope);

      expect(container.read(learningProvider).completed, 8);
      expect(await store.readString('ai_learning.same'), '{"completed":99}');
    },
  );

  test('reset deletes only the current account V2 Learning state', () async {
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
    final ProviderContainer container = _container(
      SecureStore(backend: backend),
    );
    addTearDown(container.dispose);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    await container
        .read(learningProvider.notifier)
        .apply(const LearningState(completed: 6));
    await _setScope(container, AccountStorageScope.authenticated('B'));
    await container
        .read(learningProvider.notifier)
        .apply(const LearningState(completed: 9));
    await container.read(learningProvider.notifier).reset();

    await _setScope(container, AccountStorageScope.authenticated('A'));
    expect(container.read(learningProvider).completed, 6);
    await _setScope(container, AccountStorageScope.authenticated('B'));
    expect(container.read(learningProvider).completed, 0);
  });

  test(
    'unsafe scope fails closed without legacy hydration or writes',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      await store.writeString('ai_learning', '{"completed":91}');
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);

      container.read(learningProvider);
      await _flush();
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 1));
      await container.read(learningProvider.notifier).reset();

      expect(container.read(learningProvider).completed, 0);
      expect(await store.readString('ai_learning'), '{"completed":91}');
      expect((await store.readAll()).keys, isNot(contains('ai_learning_v2.')));
    },
  );

  test(
    'scoped read failure cannot fall back to a legacy Learning key',
    () async {
      final _FailingLearningBackend backend = _FailingLearningBackend()
        ..values['ai_learning'] = '{"completed":91}'
        ..failReads = true;
      final ProviderContainer container = _container(
        SecureStore(backend: backend),
      );
      addTearDown(container.dispose);

      await _setScope(container, AccountStorageScope.authenticated('reader'));
      expect(container.read(learningProvider).completed, 0);
      expect(
        backend.readKeys,
        contains(LearningController.canonicalStorageKeyForUser('reader')),
      );
      expect(backend.readKeys, isNot(contains('ai_learning')));
    },
  );

  test(
    'write and delete failures do not mutate legacy Learning keys',
    () async {
      final _FailingLearningBackend backend = _FailingLearningBackend()
        ..values['ai_learning'] = '{"completed":91}';
      final SecureStore store = SecureStore(backend: backend);
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);
      await _setScope(container, AccountStorageScope.authenticated('writer'));

      backend.failWrites = true;
      await expectLater(
        container
            .read(learningProvider.notifier)
            .apply(const LearningState(completed: 2)),
        throwsStateError,
      );
      backend.failWrites = false;
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 3));
      backend.failDeletes = true;
      await expectLater(
        container.read(learningProvider.notifier).reset(),
        throwsStateError,
      );

      expect(await store.readString('ai_learning'), '{"completed":91}');
      expect(
        await store.readString(
          LearningController.canonicalStorageKeyForUser('writer'),
        ),
        contains('"completed":3'),
      );
    },
  );

  test('A-to-B scoped hydration failure cannot expose A Learning', () async {
    final _FailingLearningBackend backend = _FailingLearningBackend();
    final ProviderContainer container = _container(
      SecureStore(backend: backend),
    );
    addTearDown(container.dispose);
    await _setScope(container, AccountStorageScope.authenticated('A'));
    await container
        .read(learningProvider.notifier)
        .apply(const LearningState(completed: 17));

    backend.failReads = true;
    await _setScope(container, AccountStorageScope.authenticated('B'));
    expect(container.read(learningProvider).completed, 0);
    expect(backend.readKeys, isNot(contains('ai_learning')));
  });

  test(
    'direct Learning read input is recreated as B-only after a scope handoff',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final ProviderContainer container = _container(
        SecureStore(backend: backend),
      );
      addTearDown(container.dispose);
      await _setScope(container, AccountStorageScope.authenticated('A'));
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 4));
      expect(container.read(_directLearningInputProvider).completed, 4);

      await _setScope(container, AccountStorageScope.authenticated('B'));
      expect(container.read(_directLearningInputProvider).completed, 0);
    },
  );
}

ProviderContainer _container(SecureStore store) {
  return ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(_scopeProvider),
      ),
    ],
  );
}

Future<void> _setScope(
  ProviderContainer container,
  AccountStorageScope scope,
) async {
  container.read(_scopeProvider.notifier).set(scope);
  container.read(learningProvider);
  await _flush();
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _TestScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope value) => state = value;
}

class _FailingLearningBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  final List<String> readKeys = <String>[];
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<void> delete({required String key}) async {
    if (failDeletes) throw StateError('delete failed');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async {
    readKeys.add(key);
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}
