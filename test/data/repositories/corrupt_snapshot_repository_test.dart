import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/completion_event_repository.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefsStore implements SharedPrefsStore {
  _MemoryPrefsStore(this.values);

  final Map<String, String> values;

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}

void main() {
  test(
    'corrupt memory snapshot throws and cannot be overwritten by save',
    () async {
      const String corrupt = '{not-json';
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'corrupt-test',
      );
      final _MemoryPrefsStore store = _MemoryPrefsStore(<String, String>{
        MemoryRepository.canonicalStorageKeyForScope(scope): corrupt,
      });
      final MemoryRepository repository = MemoryRepository(
        store,
        storageScope: scope,
      );

      expect(repository.getMemories, throwsA(isA<StorageException>()));
      expect(
        () => repository.saveMemory(
          MemoryEntity(
            id: 'memory-1',
            text: 'Keep data safe',
            date: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<StorageException>()),
      );
      expect(store.load(MemoryRepository.canonicalStorageKeyForScope(scope)), corrupt);
    },
  );

  test(
    'corrupt completion-event snapshot throws and cannot be overwritten',
    () async {
      const String corrupt = '[not-json';
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'corrupt-test',
      );
      final _MemoryPrefsStore store = _MemoryPrefsStore(<String, String>{
        'completion_events_v2.${scope.v2Namespace}': corrupt,
      });
      final CompletionEventRepository repository = CompletionEventRepository(
        store,
        scope,
      );

      expect(repository.getEvents, throwsA(isA<StorageException>()));
      expect(
        () => repository.addEvent(
          CompletionEventEntity(
            id: 'event-1',
            eventType: CompletionEventType.completed,
            eventAt: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<StorageException>()),
      );
      expect(store.load('completion_events_v2.${scope.v2Namespace}'), corrupt);
    },
  );
}
