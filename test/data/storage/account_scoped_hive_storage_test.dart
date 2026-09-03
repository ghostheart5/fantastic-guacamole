import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late _DirectHiveStore hive;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'account_scoped_hive_storage_test_',
    );
    await Hive.close();
    Hive.init(tempDirectory.path);
    hive = _DirectHiveStore();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'scoped storage supports CRUD while preserving its migration marker',
    () async {
      final AccountScopedHiveStorage storage = _storage(
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );

      expect(storage.isWritable, isTrue);
      await storage.open();
      await storage.putAll(<String, String>{'first': 'one', 'second': 'two'});

      expect(storage.get('first'), 'one');
      expect(storage.getAll(), <dynamic, String>{
        'first': 'one',
        'second': 'two',
      });

      await storage.delete('first');
      expect(storage.get('first'), isNull);
      await storage.clear();
      expect(storage.getAll(), isEmpty);
      expect(
        storage.box().get(AccountScopedHiveStorage.migrationMarkerKey),
        LegacyScopeOwnership.provenNotOwned.name,
      );

      expect(
        () => storage.put(
          AccountScopedHiveStorage.migrationMarkerKey,
          'application-data',
        ),
        throwsArgumentError,
      );
      expect(
        () => storage.putAll(<String, String>{
          AccountScopedHiveStorage.migrationMarkerKey: 'application-data',
        }),
        throwsArgumentError,
      );
      expect(
        () => storage.delete(AccountScopedHiveStorage.migrationMarkerKey),
        throwsArgumentError,
      );

      final AccountScopedHiveStorage reopened = _storage(
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );
      await reopened.prepare();
      expect(reopened.getAll(), isEmpty);
    },
  );

  test('signed-out storage fails closed for reads and writes', () async {
    final AccountScopedHiveStorage storage = AccountScopedHiveStorage(
      baseBox: 'signed_out',
      scope: const AccountStorageScope.signedOut(),
      hive: hive,
      legacyOwnership: LegacyScopeOwnership.unownedSignedOut,
    );

    expect(storage.isWritable, isFalse);
    expect(() => storage.get('key'), throwsStateError);
    expect(storage.getAll, throwsStateError);
    await expectLater(storage.open(), throwsStateError);
    await expectLater(storage.put('key', 'value'), throwsStateError);
    await expectLater(
      storage.putAll(<String, String>{'key': 'value'}),
      throwsStateError,
    );
    await expectLater(storage.delete('key'), throwsStateError);
    await expectLater(storage.clear(), throwsStateError);
  });

  test(
    'synchronous reads use proven legacy data until preparation completes',
    () async {
      final Box<String> legacy = await hive.openBox<String>('records');
      await legacy.put('legacy', 'preserved');
      final AccountScopedHiveStorage storage = _storage(
        hive,
        LegacyScopeOwnership.provenOwned,
      );
      await hive.openBox<String>(storage.boxKey);

      expect(storage.get('legacy'), 'preserved');
      expect(storage.getAll(), <dynamic, String>{'legacy': 'preserved'});
      final Box<String> scoped = hive.box<String>(storage.boxKey);

      await storage.prepare();
      expect(storage.get('legacy'), 'preserved');
      expect(scoped.get('legacy'), 'preserved');
      expect(legacy.get('legacy'), 'preserved');
    },
  );

  test(
    'empty unowned scoped data stays unavailable until marked prepared',
    () async {
      final AccountScopedHiveStorage storage = _storage(
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );
      await hive.openBox<String>(storage.boxKey);
      final int openCallsBeforeFailedReads = hive.openBoxCalls;

      expect(() => storage.get('missing'), throwsStateError);
      expect(storage.getAll, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(hive.openBoxCalls, openCallsBeforeFailedReads);
      expect(
        hive
            .box<String>(storage.boxKey)
            .containsKey(AccountScopedHiveStorage.migrationMarkerKey),
        isFalse,
      );

      await storage.prepare();
      expect(storage.get('missing'), isNull);
      expect(storage.getAll(), isEmpty);
    },
  );

  test('legacy reads observe asynchronous preparation failures', () async {
    final Box<String> legacy = await hive.openBox<String>('records');
    await legacy.put('legacy', 'preserved');
    final AccountScopedHiveStorage storage = _storage(
      hive,
      LegacyScopeOwnership.provenOwned,
    );
    hive.failOpenBoxKey = storage.boxKey;
    final List<Object> unhandledErrors = <Object>[];

    final Future<void>? guarded = runZonedGuarded<Future<void>>(
      () async {
        await Logger.withMutedErrors(() async {
          expect(storage.get('legacy'), 'preserved');
          await Future<void>.delayed(Duration.zero);
        });
      },
      (Object error, StackTrace stackTrace) {
        unhandledErrors.add(error);
      },
    );
    await guarded;

    expect(unhandledErrors, isEmpty);
    expect(hive.isBoxOpen(storage.boxKey), isFalse);
  });
}

AccountScopedHiveStorage _storage(
  HiveStore hive,
  LegacyScopeOwnership ownership,
) {
  return AccountScopedHiveStorage(
    baseBox: 'records',
    scope: AccountStorageScope.authenticated('account-a'),
    hive: hive,
    legacyOwnership: ownership,
  );
}

class _DirectHiveStore implements HiveStore {
  int openBoxCalls = 0;
  String? failOpenBoxKey;

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    openBoxCalls += 1;
    if (key == failOpenBoxKey) {
      throw StateError('Configured open failure for $key.');
    }
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
