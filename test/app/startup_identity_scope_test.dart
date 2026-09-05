import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/identity_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/services/identity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'slow identity initialization is bounded without retrying the write',
    () async {
      final pending = Completer<String>();
      int calls = 0;
      await expectLater(
        runAccountIdentityStartup(
          scope: AccountStorageScope.authenticated('account-a'),
          timeout: Duration.zero,
          ensureIdentity: () {
            calls++;
            return pending.future;
          },
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 1);
      pending.complete('late-account-scoped-identity');
      await pending.future;
      expect(calls, 1);
    },
  );
  test(
    'old early identity call is rejected by the real storage guard',
    () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      final identity = IdentityService(
        IdentityRepository(
          store.forAccount(const AccountStorageScope.signedOut()),
        ),
      );
      await expectLater(identity.ensureIdentity(), throwsStateError);
    },
  );

  test(
    'signed-out and unsafe startup do not read or create an identity',
    () async {
      for (final scope in <AccountStorageScope>[
        const AccountStorageScope.signedOut(),
        const AccountStorageScope.unsafe(),
      ]) {
        bool called = false;
        await runAccountIdentityStartup(
          scope: scope,
          ensureIdentity: () async {
            called = true;
            throw StateError('Must not access account storage');
          },
        );
        expect(called, isFalse);
      }
    },
  );

  test('verified identity persists in its own account and is stable', () async {
    final store = SecureStore(backend: InMemorySecureStoreBackend());
    final scopeA = AccountStorageScope.authenticated('account-a');
    final scopeB = AccountStorageScope.authenticated('account-b');
    final identityA = IdentityService(
      IdentityRepository(store.forAccount(scopeA)),
    );
    final identityB = IdentityService(
      IdentityRepository(store.forAccount(scopeB)),
    );
    await runAccountIdentityStartup(
      scope: scopeA,
      ensureIdentity: identityA.ensureIdentity,
    );
    final String? firstId = await identityA.getIdentityId();
    expect(firstId, isNotEmpty);
    expect(await identityB.getIdentityId(), isNull);
    await runAccountIdentityStartup(
      scope: scopeA,
      ensureIdentity: identityA.ensureIdentity,
    );
    expect(await identityA.getIdentityId(), firstId);
    await runAccountIdentityStartup(
      scope: scopeB,
      ensureIdentity: identityB.ensureIdentity,
    );
    expect(await identityB.getIdentityId(), isNot(firstId));
    expect(await store.readString('identity_id'), isNull);
  });

  test(
    'verified identity failures still propagate instead of being hidden',
    () async {
      await expectLater(
        runAccountIdentityStartup(
          scope: AccountStorageScope.authenticated('account-a'),
          ensureIdentity: () =>
              Future<String>.error(StateError('storage failed')),
        ),
        throwsStateError,
      );
    },
  );

  test('identity startup is ordered after the verified account boundary', () {
    final stages = File(
      'lib/app/startup/startup_stages.dart',
    ).readAsStringSync();
    final initialize = stages.substring(
      stages.indexOf('Future<StartupBootstrapResult> _initializeStartup('),
      stages.indexOf('Future<void> _configureLocalTimezone('),
    );
    expect(initialize, isNot(contains('_initIdentitySafe(')));
    final coordinator = File(
      'lib/app/startup/startup_coordinator.dart',
    ).readAsStringSync();
    final boundary = coordinator.substring(
      coordinator.indexOf('Future<String?> _initializeAccountBoundarySafe('),
    );
    expect(
      boundary.indexOf('_initIdentitySafe('),
      greaterThan(boundary.indexOf('if (boundary.isStorageReady)')),
    );
    final services = File(
      'lib/state/providers/service_providers.dart',
    ).readAsStringSync();
    expect(
      services,
      contains('IdentityService(ref.watch(identityRepositoryProvider))'),
    );
  });
}
