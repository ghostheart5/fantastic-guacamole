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
    final String recoveryKey = (await firstCipher.loadExistingRecoveryKey())!;

    final SecureStore secondDevice = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher secondCipher = BackupCipher(secondDevice);
    await secondCipher.installVerifiedRecoveryKey(recoveryKey);

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

  test(
    'revealing the key never creates one on a device without a key',
    () async {
      final _RecordingBackend backend = _RecordingBackend();
      final BackupCipher cipher = BackupCipher(
        SecureStore(backend: backend),
        accountId: 'account-a',
      );

      expect(await cipher.loadExistingRecoveryKey(), isNull);
      expect(backend.writes, isEmpty);
      expect(await backend.readAll(), isEmpty);
    },
  );

  test('loadExistingRecoveryKey returns the key used for encryption', () async {
    final BackupCipher cipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
      accountId: 'account-a',
    );
    final Map<String, dynamic> encrypted = await cipher.encryptPayload(
      <String, dynamic>{'version': '3.0.0'},
    );
    final String key = (await cipher.loadExistingRecoveryKey())!;

    expect(base64Decode(key), hasLength(32));
    expect(
      await cipher.decryptPayloadWithRecoveryKey(encrypted, key),
      <String, dynamic>{'version': '3.0.0'},
    );
  });

  test('parseRecoveryKey rejects invalid recovery keys', () async {
    final BackupCipher cipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );

    expect(
      () => BackupCipher.parseRecoveryKey('not base64'),
      throwsFormatException,
    );
    expect(() => BackupCipher.parseRecoveryKey('AA=='), throwsFormatException);
    await expectLater(
      cipher.installVerifiedRecoveryKey('AA=='),
      throwsFormatException,
    );
    await expectLater(
      cipher.installUnverifiedRecoveryKey('not base64'),
      throwsFormatException,
    );
    expect(await cipher.loadExistingRecoveryKey(), isNull);
  });

  test(
    'a test decrypt with another key never changes the stored key',
    () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final BackupCipher cipher = BackupCipher(store, accountId: 'account-a');
      final Map<String, dynamic> encrypted = await cipher.encryptPayload(
        <String, dynamic>{'version': '3.0.0'},
      );
      final Map<String, String> before = await store.readAll();

      await expectLater(
        cipher.decryptPayloadWithRecoveryKey(
          encrypted,
          base64Encode(List<int>.filled(32, 9)),
        ),
        throwsA(anything),
      );

      expect(await store.readAll(), before);
    },
  );

  test('an unverified key keeps the previous key until a decrypt', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher cipher = BackupCipher(store, accountId: 'account-a');
    final Map<String, dynamic> oldBackup = await cipher.encryptPayload(
      <String, dynamic>{'version': '3.0.0'},
    );
    final String previous = (await cipher.loadExistingRecoveryKey())!;
    final String candidate = base64Encode(List<int>.filled(32, 9));
    final String other = base64Encode(List<int>.filled(32, 4));

    await cipher.installUnverifiedRecoveryKey(candidate);
    // A second unproven key must not push the original out of the rollback.
    await cipher.installUnverifiedRecoveryKey(other);
    expect(await cipher.loadExistingRecoveryKey(), other);
    expect((await store.readAll()).values, contains(previous));

    expect(await cipher.decryptPayload(oldBackup), <String, dynamic>{
      'version': '3.0.0',
    });
    expect(await cipher.loadExistingRecoveryKey(), previous);
    expect((await store.readAll()).values.where((v) => v == other), isEmpty);
  });

  test('a decrypt with the new key retires the rollback key', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher cipher = BackupCipher(store, accountId: 'account-a');
    await cipher.encryptPayload(<String, dynamic>{'version': '3.0.0'});
    final String previous = (await cipher.loadExistingRecoveryKey())!;
    final String candidate = base64Encode(List<int>.filled(32, 9));

    await cipher.installUnverifiedRecoveryKey(candidate);
    final Map<String, dynamic> newBackup = await cipher.encryptPayload(
      <String, dynamic>{'version': '6.0.0'},
    );
    await cipher.decryptPayload(newBackup);

    expect(await cipher.loadExistingRecoveryKey(), candidate);
    expect((await store.readAll()).values, isNot(contains(previous)));
  });

  test('a backup neither key opens still fails and changes nothing', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final BackupCipher cipher = BackupCipher(store, accountId: 'account-a');
    await cipher.encryptPayload(<String, dynamic>{'version': '3.0.0'});
    await cipher.installUnverifiedRecoveryKey(
      base64Encode(List<int>.filled(32, 9)),
    );
    final Map<String, String> before = await store.readAll();
    final Map<String, dynamic> foreign = await BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    ).encryptPayload(<String, dynamic>{'version': '3.0.0'});

    await expectLater(cipher.decryptPayload(foreign), throwsA(anything));
    expect(await store.readAll(), before);
  });

  test(
    'a first key made by automatic backup during an import stays recoverable',
    () async {
      final _GatedFirstReadBackend backend = _GatedFirstReadBackend(
        'cloud_backup_encryption_key_v1',
      );
      final SecureStore store = SecureStore(backend: backend);
      final KeyedMutationCoordinator mutations = KeyedMutationCoordinator();
      final BackupCipher importing = BackupCipher(
        store,
        mutationCoordinator: mutations,
      );
      final BackupCipher automatic = BackupCipher(
        store,
        mutationCoordinator: mutations,
      );
      final String imported = base64Encode(List<int>.filled(32, 9));

      // The import starts reading the current key while none exists yet.
      final Future<void> import = importing.installUnverifiedRecoveryKey(
        imported,
      );
      await backend.firstRead;
      // Automatic backup on the same device now needs a key to upload with.
      final Future<Map<String, dynamic>> upload = automatic.encryptPayload(
        <String, dynamic>{'version': '6.0.0'},
      );
      await pumpEventQueue();
      backend.release();
      await import;
      final Map<String, dynamic> uploaded = await upload;

      // Whichever ran first, the key the upload used is still on the device.
      expect(await importing.decryptPayload(uploaded), <String, dynamic>{
        'version': '6.0.0',
      });
    },
  );

  test(
    'a rollback is not restored over a key installed during the decrypt',
    () async {
      final _GatedFirstReadBackend backend = _GatedFirstReadBackend(
        'cloud_backup_encryption_key_v1.rollback',
        armed: false,
      );
      final SecureStore store = SecureStore(backend: backend);
      final KeyedMutationCoordinator mutations = KeyedMutationCoordinator();
      final BackupCipher cipher = BackupCipher(
        store,
        mutationCoordinator: mutations,
      );
      final Map<String, dynamic> oldBackup = await cipher.encryptPayload(
        <String, dynamic>{'version': '3.0.0'},
      );
      await cipher.installUnverifiedRecoveryKey(
        base64Encode(List<int>.filled(32, 9)),
      );
      final String verified = base64Encode(List<int>.filled(32, 4));

      backend.armed = true;
      final Future<Map<String, dynamic>> decrypt = cipher.decryptPayload(
        oldBackup,
      );
      await backend.firstRead;
      // A proven key is installed while the decrypt is still running.
      await BackupCipher(
        store,
        mutationCoordinator: mutations,
      ).installVerifiedRecoveryKey(verified);
      backend.release();
      await decrypt;

      expect(await cipher.loadExistingRecoveryKey(), verified);
    },
  );

  test(
    'a verified key replaces the stored key and drops the rollback',
    () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final BackupCipher cipher = BackupCipher(store, accountId: 'account-a');
      await cipher.encryptPayload(<String, dynamic>{'version': '3.0.0'});
      await cipher.installUnverifiedRecoveryKey(
        base64Encode(List<int>.filled(32, 9)),
      );
      final String verified = base64Encode(List<int>.filled(32, 4));

      await cipher.installVerifiedRecoveryKey(verified);

      expect(await cipher.loadExistingRecoveryKey(), verified);
      expect(await store.readAll(), hasLength(1));
    },
  );

  test('new account-scoped backup keys are isolated', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );

    final String first = await _keyUsedForEncryption(
      BackupCipher(store, accountId: 'account-a'),
    );
    final String second = await _keyUsedForEncryption(
      BackupCipher(store, accountId: 'account-b'),
    );

    expect(second, isNot(first));
  });

  test('account-scoped cipher preserves legacy backup recovery', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final String legacy = await _keyUsedForEncryption(BackupCipher(store));

    final String? migrated = await BackupCipher(
      store,
      accountId: 'account-a',
    ).loadExistingRecoveryKey();
    final String? otherAccount = await BackupCipher(
      store,
      accountId: 'account-b',
    ).loadExistingRecoveryKey();

    expect(migrated, legacy);
    expect(otherAccount, isNull);
    // Legacy key, its owner, and account A's claimed copy; nothing for B.
    expect((await store.readAll()).keys, hasLength(3));
  });

  test('concurrent accounts cannot both claim one legacy key', () async {
    final String legacy = base64Encode(List<int>.filled(32, 7));
    final _LegacyClaimBackend backend = _LegacyClaimBackend(legacy);
    final SecureStore store = SecureStore(backend: backend);
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final Future<String?> first = BackupCipher(
      store,
      accountId: 'account-a',
      mutationCoordinator: coordinator,
    ).loadExistingRecoveryKey();
    await backend.firstOwnerRead;
    final Future<String?> second = BackupCipher(
      store,
      accountId: 'account-b',
      mutationCoordinator: coordinator,
    ).loadExistingRecoveryKey();
    await pumpEventQueue();
    expect(backend.ownerReadCount, 1);

    backend.releaseOwnerReads();
    final List<String?> keys = await Future.wait(<Future<String?>>[
      first,
      second,
    ]);

    expect(keys, <String?>[legacy, null]);
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

class _RecordingBackend extends InMemorySecureStoreBackend {
  final List<String> writes = <String>[];

  @override
  Future<void> write({required String key, required String value}) {
    writes.add(key);
    return super.write(key: key, value: value);
  }
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

/// Holds the first read of [gatedKey] until [release] is called.
class _GatedFirstReadBackend extends InMemorySecureStoreBackend {
  _GatedFirstReadBackend(this.gatedKey, {this.armed = true});

  final String gatedKey;
  bool armed;
  final Completer<void> _firstRead = Completer<void>();
  final Completer<void> _release = Completer<void>();

  Future<void> get firstRead => _firstRead.future;

  void release() => _release.complete();

  @override
  Future<String?> read({required String key}) async {
    if (armed && key == gatedKey && !_firstRead.isCompleted) {
      // Read the value first, as a slow platform read would.
      final String? value = await super.read(key: key);
      _firstRead.complete();
      await _release.future;
      return value;
    }
    return super.read(key: key);
  }
}

Future<String> _keyUsedForEncryption(BackupCipher cipher) async {
  await cipher.encryptPayload(<String, dynamic>{'version': '3.0.0'});
  return (await cipher.loadExistingRecoveryKey())!;
}
