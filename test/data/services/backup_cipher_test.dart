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
