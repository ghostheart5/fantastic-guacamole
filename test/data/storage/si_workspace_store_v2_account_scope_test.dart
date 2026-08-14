import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/si_workspace_store.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_Scope, AccountStorageScope> _scope =
    NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

void main() {
  test(
    'workspace V2 isolates A to B to A, restarts, and preserves legacy',
    () async {
      final _Backend backend = _Backend()
        ..values[SiWorkspaceStore.legacyStorageKey] =
            '{"marker":"LEGACY_WORKSPACE_SENTINEL"}';
      final SecureStore secureStore = SecureStore(backend: backend);
      final SiWorkspaceStore a = SiWorkspaceStore(
        secureStore,
        storageScope: AccountStorageScope.authenticated('A'),
      );
      final SiWorkspaceStore b = SiWorkspaceStore(
        secureStore,
        storageScope: AccountStorageScope.authenticated('B'),
      );

      await a.save(<String, dynamic>{'marker': 'A_WORKSPACE_ONLY'});
      expect((await a.load())?['marker'], 'A_WORKSPACE_ONLY');
      expect(await b.load(), isNull);
      await b.save(<String, dynamic>{'marker': 'B_WORKSPACE_ONLY'});
      expect((await b.load())?['marker'], 'B_WORKSPACE_ONLY');
      expect((await a.load())?['marker'], 'A_WORKSPACE_ONLY');

      final SiWorkspaceStore restartedA = SiWorkspaceStore(
        secureStore,
        storageScope: AccountStorageScope.authenticated('A'),
      );
      expect((await restartedA.load())?['marker'], 'A_WORKSPACE_ONLY');
      expect(
        backend.values[SiWorkspaceStore.legacyStorageKey],
        '{"marker":"LEGACY_WORKSPACE_SENTINEL"}',
      );
    },
  );

  test(
    'workspace V2 fails closed and scoped failures do not touch legacy',
    () async {
      final _Backend backend = _Backend()
        ..values[SiWorkspaceStore.legacyStorageKey] =
            '{"marker":"LEGACY_WORKSPACE_SENTINEL"}';
      final SecureStore secureStore = SecureStore(backend: backend);
      final SiWorkspaceStore unsafe = SiWorkspaceStore(
        secureStore,
        storageScope: const AccountStorageScope.unsafe(),
      );
      await expectLater(unsafe.load(), throwsStateError);
      expect(
        () => unsafe.save(<String, dynamic>{'marker': 'UNSAFE'}),
        throwsStateError,
      );

      final SiWorkspaceStore a = SiWorkspaceStore(
        secureStore,
        storageScope: AccountStorageScope.authenticated('A'),
      );
      final SiWorkspaceStore b = SiWorkspaceStore(
        secureStore,
        storageScope: AccountStorageScope.authenticated('B'),
      );
      await a.save(<String, dynamic>{'marker': 'A_WORKSPACE_ONLY'});
      backend.failReads = true;
      await expectLater(b.load(), throwsStateError);
      backend.failReads = false;
      backend.failWrites = true;
      await expectLater(
        b.save(<String, dynamic>{'marker': 'B_FAILED_WORKSPACE'}),
        throwsStateError,
      );
      backend.failWrites = false;
      await b.save(<String, dynamic>{'marker': 'B_WORKSPACE_ONLY'});

      expect((await a.load())?['marker'], 'A_WORKSPACE_ONLY');
      expect((await b.load())?['marker'], 'B_WORKSPACE_ONLY');
      expect(
        backend.values[SiWorkspaceStore.legacyStorageKey],
        '{"marker":"LEGACY_WORKSPACE_SENTINEL"}',
      );
    },
  );

  test('workspace provider recreates across A, signed-out, B, and C', () async {
    final _Backend backend = _Backend()
      ..values[SiWorkspaceStore.legacyStorageKey] =
          '{"marker":"LEGACY_WORKSPACE_SENTINEL"}';
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_scope),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _set(container, AccountStorageScope.authenticated('A'));
    final SiWorkspaceStore a = container.read(siWorkspaceStoreProvider);
    await a.save(<String, dynamic>{'marker': 'A_WORKSPACE_ONLY'});
    await _set(container, AccountStorageScope.authenticated('A'));
    expect(
      (await container.read(siWorkspaceStoreProvider).load())?['marker'],
      'A_WORKSPACE_ONLY',
    );

    await _set(container, const AccountStorageScope.signedOut());
    final SiWorkspaceStore signedOut = container.read(siWorkspaceStoreProvider);
    expect(identical(a, signedOut), isFalse);
    await expectLater(signedOut.load(), throwsStateError);
    expect(await container.read(siEngineStateProvider.future), isNull);

    await _set(container, AccountStorageScope.authenticated('B'));
    final SiWorkspaceStore b = container.read(siWorkspaceStoreProvider);
    expect(identical(a, b), isFalse);
    expect(await b.load(), isNull);
    await b.save(<String, dynamic>{'marker': 'B_WORKSPACE_ONLY'});
    expect((await b.load())?['marker'], 'B_WORKSPACE_ONLY');

    await _set(container, AccountStorageScope.authenticated('A'));
    expect(
      (await container.read(siWorkspaceStoreProvider).load())?['marker'],
      'A_WORKSPACE_ONLY',
    );
    await _set(container, AccountStorageScope.authenticated('C'));
    expect(await container.read(siWorkspaceStoreProvider).load(), isNull);
    expect(
      backend.values[SiWorkspaceStore.legacyStorageKey],
      '{"marker":"LEGACY_WORKSPACE_SENTINEL"}',
    );
  });
}

Future<void> _set(
  ProviderContainer container,
  AccountStorageScope scope,
) async {
  container.read(_scope.notifier).set(scope);
  container.invalidate(siWorkspaceStoreProvider);
  container.invalidate(siEngineStateProvider);
  await Future<void>.delayed(Duration.zero);
}

class _Scope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope value) => state = value;
}

class _Backend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async {
    if (failReads) throw StateError('read failure');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failure');
    values[key] = value;
  }
}
