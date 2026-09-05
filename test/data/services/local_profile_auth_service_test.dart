import 'dart:async';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SecureStore store;
  LocalProfileAuthService service({
    Future<void> Function(String)? delete,
    Future<void> Function(String)? close,
  }) => LocalProfileAuthService(
    store: store,
    onProfileDeleted: delete ?? (_) async {},
    onBeforeClosed: close ?? (_) async {},
  );
  setUp(() => store = SecureStore(backend: InMemorySecureStoreBackend()));

  test(
    'persists a random local identity across service restart without cloud claims',
    () async {
      final first = service();
      expect(await first.authStateChanges().first, isNull);
      final user = await first.createProfile(displayName: '  Local person  ');
      expect(user.id, matches(RegExp(r'^local-[a-f0-9]{32}$')));
      expect(user.email, isNull);
      expect(user.emailVerified, isFalse);
      expect(user.isLocalProfile, isTrue);
      expect(user.hasInternalAdvisorAccess, isFalse);
      expect(await first.getIdToken(forceRefresh: true), isNull);
      final restarted = service();
      final loaded = await restarted.authStateChanges().first;
      expect(loaded?.id, user.id);
      expect(loaded?.displayName, 'Local person');
      expect(loaded?.isLocalProfile, isTrue);
      await first.dispose();
      await restarted.dispose();
    },
  );

  test(
    'closing and reopening preserves both identity and scoped data',
    () async {
      final closed = <String>[];
      final first = service(close: (id) async => closed.add(id));
      final user = await first.createProfile();
      final scoped = store.forAccount(
        AccountStorageScope.authenticated(user.id),
      );
      await scoped.writeString('private', 'planning data');
      await first.signOut();
      expect(closed, [user.id]);
      expect(first.currentUser, isNull);
      final restarted = service();
      await restarted.initialize();
      expect(restarted.currentUser, isNull);
      expect((await restarted.openProfile()).id, user.id);
      expect(await scoped.readString('private'), 'planning data');
      await first.dispose();
      await restarted.dispose();
    },
  );

  test(
    'deletion journal survives failure and restart, blocks open/create, and retries same profile',
    () async {
      final first = service(
        delete: (_) async => throw StateError('cleanup failed'),
      );
      final user = await first.createProfile();
      await expectLater(
        first.deleteCurrentAccount(password: ''),
        throwsStateError,
      );
      expect(first.currentUser, isNull);
      expect(first.hasPendingDeletion, isTrue);
      await expectLater(first.openProfile(), throwsStateError);
      await expectLater(first.createProfile(), throwsStateError);
      final deleted = <String>[];
      final restarted = service(delete: (id) async => deleted.add(id));
      expect(await restarted.authStateChanges().first, isNull);
      expect(restarted.pendingDeletionAccountId, user.id);
      expect(
        (await restarted.deleteCurrentAccount(password: '')).isCompleted,
        isTrue,
      );
      expect(deleted, [user.id]);
      expect(
        await store.readString(LocalProfileAuthService.profileKey),
        isNull,
      );
      expect(restarted.hasStoredProfile, isFalse);
      final replacement = await restarted.createProfile();
      expect(replacement.id, isNot(user.id));
      await first.dispose();
      await restarted.dispose();
    },
  );

  test(
    'journals before cleanup and removes identity only after cleanup completes',
    () async {
      final cleanupStarted = Completer<void>();
      final cleanupDone = Completer<void>();
      final instance = service(
        delete: (_) async {
          expect(
            await store.readString(LocalProfileAuthService.profileKey),
            contains('deleting'),
          );
          cleanupStarted.complete();
          await cleanupDone.future;
        },
      );
      await instance.createProfile();
      final deletion = instance.deleteCurrentAccount(password: '');
      await cleanupStarted.future;
      expect(
        await store.readString(LocalProfileAuthService.profileKey),
        isNotNull,
      );
      cleanupDone.complete();
      await deletion;
      expect(
        await store.readString(LocalProfileAuthService.profileKey),
        isNull,
      );
      await instance.dispose();
    },
  );

  test(
    'cloud operations fail honestly and metadata cannot grant local identity',
    () async {
      final instance = service();
      await instance.createProfile();
      await expectLater(
        instance.signIn(email: 'x@y.z', password: 'anything'),
        throwsA(isA<FirebaseAuthException>()),
      );
      await expectLater(
        instance.signInWithGoogle(),
        throwsA(isA<FirebaseAuthException>()),
      );
      await expectLater(
        instance.sendEmailVerification(),
        throwsA(isA<FirebaseAuthException>()),
      );
      const cloud = User(
        id: 'cloud',
        emailVerified: false,
        appMetadata: {'isLocalProfile': true},
      );
      expect(cloud.isLocalProfile, isFalse);
      await instance.dispose();
    },
  );

  test(
    'corrupt stored profile fails closed without replacing its identity',
    () async {
      await store.writeString(LocalProfileAuthService.profileKey, '{invalid');
      final instance = service();
      await expectLater(instance.initialize(), throwsFormatException);
      await expectLater(instance.createProfile(), throwsFormatException);
      expect(
        await store.readString(LocalProfileAuthService.profileKey),
        '{invalid',
      );
      await instance.dispose();
    },
  );
  test(
    'failed identity removal remains journaled and can retry without touching another scope',
    () async {
      final backend = _FailingDeleteBackend();
      store = SecureStore(backend: backend);
      final cloud = store.forAccount(
        AccountStorageScope.authenticated('cloud-owner'),
      );
      await cloud.writeString('private', 'preserved');
      final local = service(
        delete: (id) =>
            store.forAccount(AccountStorageScope.authenticated(id)).deleteAll(),
      );
      final user = await local.createProfile();
      final localScope = store.forAccount(
        AccountStorageScope.authenticated(user.id),
      );
      await localScope.writeString('private', 'remove');
      backend.failIdentityDelete = true;
      await expectLater(
        local.deleteCurrentAccount(password: ''),
        throwsStateError,
      );
      expect(local.hasPendingDeletion, isTrue);
      expect(local.currentUser, isNull);
      expect(await localScope.readString('private'), isNull);
      expect(await cloud.readString('private'), 'preserved');
      backend.failIdentityDelete = false;
      await local.deleteCurrentAccount(password: '');
      expect(
        await store.readString(LocalProfileAuthService.profileKey),
        isNull,
      );
      expect(await cloud.readString('private'), 'preserved');
      await local.dispose();
    },
  );
}

class _FailingDeleteBackend extends InMemorySecureStoreBackend {
  bool failIdentityDelete = false;
  @override
  Future<void> delete({required String key}) async {
    if (failIdentityDelete && key == LocalProfileAuthService.profileKey) {
      throw StateError('Secure storage delete failed');
    }
    return super.delete(key: key);
  }
}
