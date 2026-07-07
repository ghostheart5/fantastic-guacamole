import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemorySharedPrefsStore store;
  late MemoryRepository repository;

  setUp(() {
    store = _InMemorySharedPrefsStore();
    repository = MemoryRepository(store);
  });

  test('returns paged memories newest first with cursor continuation', () async {
    await repository.saveMemory(
      MemoryEntity(id: 'memory-1', text: 'First', date: DateTime.utc(2026, 7, 4, 10)),
    );
    await repository.saveMemory(
      MemoryEntity(id: 'memory-2', text: 'Second', date: DateTime.utc(2026, 7, 4, 11)),
    );
    await repository.saveMemory(
      MemoryEntity(id: 'memory-3', text: 'Third', date: DateTime.utc(2026, 7, 4, 12)),
    );

    final firstPage = repository.getMemoriesPage(limit: 2);
    final secondPage = repository.getMemoriesPage(cursor: firstPage.nextCursor, limit: 2);

    expect(firstPage.items.map((MemoryEntity memory) => memory.id), <String>[
      'memory-3',
      'memory-2',
    ]);
    expect(firstPage.nextCursor, 'memory-2');
    expect(secondPage.items.map((MemoryEntity memory) => memory.id), <String>['memory-1']);
    expect(secondPage.nextCursor, isNull);
  });
}

class _InMemorySharedPrefsStore implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }
}
