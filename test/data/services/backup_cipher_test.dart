import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery key decrypts an encrypted backup on another device', () async {
    final SecureStore firstDevice = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher firstCipher = BackupCipher(firstDevice);
    final Map<String, dynamic> encrypted = await firstCipher.encryptPayload(
      <String, dynamic>{
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'task-1'},
        ],
      },
    );
    final String recoveryKey = await firstCipher.exportRecoveryKey();

    final SecureStore secondDevice = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher secondCipher = BackupCipher(secondDevice);
    await secondCipher.importRecoveryKey(recoveryKey);

    final Map<String, dynamic> restored = await secondCipher.decryptPayload(
      encrypted,
    );

    expect(restored['version'], '3.0.0');
    expect(
      ((restored['tasks'] as List<dynamic>).single
          as Map<String, dynamic>)['id'],
      'task-1',
    );
  });

  test('importRecoveryKey rejects invalid recovery keys', () async {
    final BackupCipher cipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );

    await expectLater(
      cipher.importRecoveryKey('not base64'),
      throwsFormatException,
    );
    await expectLater(cipher.importRecoveryKey('AA=='), throwsFormatException);
  });

  test('new account-scoped backup keys are isolated', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );

    final String first = await BackupCipher(
      store,
      accountId: 'account-a',
    ).exportRecoveryKey();
    final String second = await BackupCipher(
      store,
      accountId: 'account-b',
    ).exportRecoveryKey();

    expect(second, isNot(first));
  });

  test('account-scoped cipher preserves legacy backup recovery', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final String legacy = await BackupCipher(store).exportRecoveryKey();

    final String migrated = await BackupCipher(
      store,
      accountId: 'account-a',
    ).exportRecoveryKey();
    final String otherAccount = await BackupCipher(
      store,
      accountId: 'account-b',
    ).exportRecoveryKey();

    expect(migrated, legacy);
    expect(otherAccount, isNot(legacy));
    expect((await store.readAll()).keys, hasLength(4));
  });

  test('concurrent accounts cannot both claim one legacy key', () async {
    final _LegacyClaimBackend backend = _LegacyClaimBackend(
      base64Encode(List<int>.filled(32, 7)),
    );
    final SecureStore store = SecureStore(backend: backend);
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final Future<String> first = BackupCipher(
      store,
      accountId: 'account-a',
      mutationCoordinator: coordinator,
    ).exportRecoveryKey();
    await backend.firstOwnerRead;
    final Future<String> second = BackupCipher(
      store,
      accountId: 'account-b',
      mutationCoordinator: coordinator,
    ).exportRecoveryKey();
    await pumpEventQueue();
    expect(backend.ownerReadCount, 1);

    backend.releaseOwnerReads();
    final List<String> keys = await Future.wait(<Future<String>>[
      first,
      second,
    ]);

    expect(keys[1], isNot(keys[0]));
  });

  test('reports when an encrypted backup needs its recovery key', () async {
    final BackupCipher firstCipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );
    final Map<String, dynamic> encrypted = await firstCipher.encryptPayload(
      <String, dynamic>{'version': '3.0.0'},
    );
    final BackupCipher replacementDevice = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );

    await expectLater(
      replacementDevice.decryptPayload(encrypted),
      throwsA(isA<BackupRecoveryKeyRequiredException>()),
    );
  });

  test(
    'rejects malformed plaintext payloads instead of treating them as backups',
    () async {
      final BackupCipher cipher = BackupCipher(
        SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        cipher.decryptPayload(<String, dynamic>{'tasks': <Object?>[]}),
        throwsFormatException,
      );
    },
  );

  test('identifies only the supported legacy plaintext full-backup shape', () {
    final BackupCipher cipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );

    expect(
      cipher.isLegacyPlaintextBackup(<String, dynamic>{
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[],
      }),
      isTrue,
    );
    expect(
      cipher.isLegacyPlaintextBackup(<String, dynamic>{
        'format': 'unknown',
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[],
      }),
      isFalse,
    );
  });
}

class _LegacyClaimBackend implements SecureStoreBackend {
  _LegacyClaimBackend(String legacyKey) {
    _values['cloud_backup_encryption_key_v1'] = legacyKey;
  }

  final Map<String, String> _values = <String, String>{};
  final Completer<void> _firstOwnerRead = Completer<void>();
  final Completer<void> _releaseOwnerReads = Completer<void>();
  int ownerReadCount = 0;

  Future<void> get firstOwnerRead => _firstOwnerRead.future;

  void releaseOwnerReads() => _releaseOwnerReads.complete();

  @override
  Future<String?> read({required String key}) async {
    if (key == 'cloud_backup_encryption_key_v1_owner_digest') {
      ownerReadCount += 1;
      if (!_firstOwnerRead.isCompleted) _firstOwnerRead.complete();
      await _releaseOwnerReads.future;
    }
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.unmodifiable(_values);
}
