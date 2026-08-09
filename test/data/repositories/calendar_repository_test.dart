import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/repositories/calendar_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects malformed calendar dates without replacing stored data', () async {
    const String corrupt = '[{"id":"entry-1","title":"Bad","start":"invalid","end":"invalid"}]';
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    await store.writeString('calendar_entries_v1', corrupt);
    final CalendarRepository repository = CalendarRepository(store);

    await expectLater(repository.getEntries(), throwsA(isA<StorageException>()));
    await expectLater(
      repository.saveEntry(
        CalendarEntryEntity(
          id: 'entry-2',
          title: 'Valid entry',
          start: DateTime.utc(2026, 8, 4, 9),
          end: DateTime.utc(2026, 8, 4, 10),
        ),
      ),
      throwsA(isA<StorageException>()),
    );
    expect(await store.readString('calendar_entries_v1'), corrupt);
  });
}
