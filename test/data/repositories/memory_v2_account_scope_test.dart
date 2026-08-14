import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Memory V2 isolates A to B to A and preserves legacy', () async {
    final _Store store = _Store()..values['memories_v1'] = '[]';
    final MemoryRepository a = MemoryRepository(store, storageScope: AccountStorageScope.authenticated('A'));
    final MemoryRepository b = MemoryRepository(store, storageScope: AccountStorageScope.authenticated('B'));
    await a.saveMemory(_memory('same', 'A_MEMORY_ONLY'));
    expect(a.getMemories().single.text, 'A_MEMORY_ONLY');
    expect(b.getMemories(), isEmpty);
    await b.saveMemory(_memory('same', 'B_MEMORY_ONLY'));
    expect(b.getMemories().single.text, 'B_MEMORY_ONLY');
    expect(a.getMemories().single.text, 'A_MEMORY_ONLY');
    await b.deleteMemory('same');
    expect(b.getMemories(), isEmpty);
    expect(a.getMemories().single.text, 'A_MEMORY_ONLY');
    expect(store.values['memories_v1'], '[]');
  });

  test('Memory V2 fails closed and never falls back to legacy', () async {
    final _Store store = _Store()..values['memories_v1'] = '[{"id":"legacy"}]';
    final MemoryRepository unsafe = MemoryRepository(store, storageScope: const AccountStorageScope.unsafe());
    expect(unsafe.getMemories, throwsStateError);
    expect(() => unsafe.saveMemory(_memory('x', 'unsafe')), throwsStateError);
    expect(store.values['memories_v1'], '[{"id":"legacy"}]');
  });

  test('scoped read and write failures preserve legacy and other account state', () async {
    final _Store store = _Store()..values['memories_v1'] = '[{"id":"LEGACY_MEMORY_SENTINEL"}]';
    final MemoryRepository a = MemoryRepository(store, storageScope: AccountStorageScope.authenticated('A'));
    final MemoryRepository b = MemoryRepository(store, storageScope: AccountStorageScope.authenticated('B'));
    await a.saveMemory(_memory('a', 'A_MEMORY_ONLY'));
    await b.saveMemory(_memory('b', 'B_GOOD'));
    store.failReads = true;
    expect(b.getMemories, throwsStateError);
    expect(store.values['memories_v1'], '[{"id":"LEGACY_MEMORY_SENTINEL"}]');
    store.failReads = false;
    store.failWrites = true;
    await expectLater(b.saveMemory(_memory('failed', 'B_FAILED_MEMORY')), throwsStateError);
    expect(b.getMemories().map((e) => e.text), contains('B_GOOD'));
    expect(b.getMemories().map((e) => e.text), isNot(contains('B_FAILED_MEMORY')));
    expect(a.getMemories().map((e) => e.text), contains('A_MEMORY_ONLY'));
    store.failWrites = false;
    await b.saveMemory(_memory('failed', 'B_FAILED_MEMORY'));
    expect(b.getMemories().map((e) => e.text), contains('B_FAILED_MEMORY'));
    expect(store.values['memories_v1'], '[{"id":"LEGACY_MEMORY_SENTINEL"}]');
  });
}

MemoryEntity _memory(String id, String text) => MemoryEntity(id: id, text: text, date: DateTime.utc(2026));

class _Store implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) { if (failReads) throw StateError('read failure'); return values[key]; }
  @override Future<void> save(String key, String value) async { if (failWrites) throw StateError('write failure'); values[key] = value; }
}
