import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    await Hive.close();
    tempDirectory = await Directory.systemTemp.createTemp(
      'profile_account_scope_test_',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'profile legacy Hive state migrates only for its proven owner and remains preserved',
    () async {
      final Box<String> legacy = await Hive.openBox<String>(HiveBoxes.profile);
      final String encoded = jsonEncode(
        ProfileState(name: 'Account A', xp: 25).toJson(),
      );
      await legacy.put('profile_state', encoded);

      final InMemorySecureStoreBackend accountABackend =
          InMemorySecureStoreBackend();
      final ProviderContainer accountA = _profileContainer(
        accountId: 'account-a',
        ownership: LegacyScopeOwnership.provenOwned,
        backend: accountABackend,
      );

      expect(accountA.read(profileProvider).name, 'ChronoSpark User');
      await _waitForProfileName(accountA, 'Account A');

      expect(accountA.read(profileProvider).name, 'Account A');
      final String accountAProfileKey = AccountStorageNamespace.authenticated(
        'account-a',
      ).scopedKey('profile_state_v2');
      expect((await accountABackend.read(key: accountAProfileKey)), isNotNull);
      expect(legacy.get('profile_state'), encoded);
      accountA.dispose();

      final ProviderContainer accountB = _profileContainer(
        accountId: 'account-b',
        ownership: LegacyScopeOwnership.provenNotOwned,
        backend: InMemorySecureStoreBackend(),
      );
      expect(accountB.read(profileProvider).name, 'ChronoSpark User');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(accountB.read(profileProvider).name, 'ChronoSpark User');
      expect(legacy.get('profile_state'), encoded);
      accountB.dispose();
    },
  );
}

Future<void> _waitForProfileName(
  ProviderContainer container,
  String expected,
) async {
  for (int attempt = 0; attempt < 50; attempt += 1) {
    if (container.read(profileProvider).name == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ProviderContainer _profileContainer({
  required String accountId,
  required LegacyScopeOwnership ownership,
  required SecureStoreBackend backend,
}) {
  return ProviderContainer(
    overrides: [
      hiveStoreProvider.overrideWithValue(_DirectHiveStore()),
      secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(accountId),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(ownership),
    ],
  );
}

final class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) return Hive.box<T>(key);
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<dynamic> box = Hive.isBoxOpen(key)
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}
