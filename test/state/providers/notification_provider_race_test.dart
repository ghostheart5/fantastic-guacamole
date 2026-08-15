import 'dart:convert';

import '../../helpers/controllable_secure_store_backend.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rapid A to B to C ignores delayed B notification load', () async {
    final ControllableSecureStoreBackend backend =
        ControllableSecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    AccountStorageScope scope = AccountStorageScope.authenticated('A');
    await _seed(store, scope, 'A');
    final ProviderContainer c = _container(store, () => scope);
    addTearDown(c.dispose);
    c.listen(notificationProvider, (_, _) {});
    await _settle();
    final String bKey = NotificationsRepository.canonicalStorageKeyForScope(
      AccountStorageScope.authenticated('B'),
    );
    backend.holdNextReadFor(bKey);
    scope = AccountStorageScope.authenticated('B');
    c.invalidate(accountStorageScopeProvider);
    await backend.waitUntilReadStarted(bKey);
    scope = AccountStorageScope.authenticated('C');
    c.invalidate(accountStorageScopeProvider);
    await _seed(store, scope, 'C');
    await _settle();
    backend.releaseHeldRead();
    await _settle();
    expect(_titles(c), <String>['C']);
  });

  test('delayed A result cannot overwrite B notification state', () async {
    final ControllableSecureStoreBackend backend =
        ControllableSecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    AccountStorageScope scope = AccountStorageScope.authenticated('A');
    final String aKey = NotificationsRepository.canonicalStorageKeyForScope(scope);
    await _seed(store, scope, 'A');
    backend.holdNextReadFor(aKey);
    final ProviderContainer c = _container(store, () => scope);
    addTearDown(c.dispose);
    c.listen(notificationProvider, (_, _) {});
    await backend.waitUntilReadStarted(aKey);
    scope = AccountStorageScope.authenticated('B');
    c.invalidate(accountStorageScopeProvider);
    await _seed(store, scope, 'B');
    await _settle();
    backend.releaseHeldRead();
    await _settle();
    expect(_titles(c), <String>['B']);
  });
}

ProviderContainer _container(
  SecureStore store,
  AccountStorageScope Function() scope,
) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWith((Ref ref) => scope()),
    secureStoreProvider.overrideWithValue(store),
  ],
);
Future<void> _seed(
  SecureStore store,
  AccountStorageScope scope,
  String title,
) => store.writeString(
  NotificationsRepository.canonicalStorageKeyForScope(scope),
  jsonEncode(<Map<String, Object>>[
    <String, Object>{
      'id': title,
      'title': title,
      'message': title,
      'scheduledAt': DateTime.utc(2027).toIso8601String(),
      'isEnabled': true,
      'isRead': false,
    },
  ]),
);
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

List<String> _titles(ProviderContainer c) => c
    .read(notificationProvider)
    .map((NotificationEntity n) => n.title)
    .toList();
