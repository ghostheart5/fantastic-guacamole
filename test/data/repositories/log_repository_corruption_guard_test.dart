import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refuses to append log when persisted payload is hard-corrupted', () async {
    final SecureStore store = SecureStore(backend: InMemorySecureStoreBackend());
    final LogRepository repository = LogRepository(store);

    await store.writeString('chrono_log_entries_v2', '{bad-json');

    await expectLater(
      repository.addLog(
        LogEntryEntity(
          id: 'log-1',
          source: 'system',
          message: 'hello',
          timestamp: DateTime.utc(2026, 1, 2),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
