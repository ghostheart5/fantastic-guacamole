import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';

class FlowmapRepository implements IFlowmapRepository {
  FlowmapRepository({required HiveStorage<String> storage})
    // Public constructor keeps the established `storage` parameter.
    // ignore: prefer_initializing_formals
    : _storage = storage,
      _secureStore = null;

  FlowmapRepository.secure(
    SecureStore secureStore, {
    HiveStorage<String>? legacyStorage,
  }) : _storage = legacyStorage,
       _secureStore = secureStore;

  static const String _secureKey = 'flowmap_entries_v2';
  final HiveStorage<String>? _storage;
  final SecureStore? _secureStore;

  @override
  Future<List<FlowmapNode>> getNodes() async {
    final Map<dynamic, String> entries = await _entries();
    return entries.values.map(FlowmapNode.fromRaw).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> saveNodes(List<FlowmapNode> nodes) async {
    if (_secureStore != null) {
      await _write(<dynamic, String>{
        for (final FlowmapNode node in nodes) node.id: node.toRaw(),
      });
    } else {
      final HiveStorage<String> storage = _storage!;
      await storage.open();
      for (final FlowmapNode node in nodes) {
        await storage.put(node.id, node.toRaw());
      }
    }
  }

  @override
  Future<void> saveNode(FlowmapNode node) async {
    if (_secureStore != null) {
      final Map<dynamic, String> entries = await _entries();
      entries[node.id] = node.toRaw();
      await _write(entries);
    } else {
      final HiveStorage<String> storage = _storage!;
      await storage.open();
      await storage.put(node.id, node.toRaw());
    }
  }

  @override
  Future<void> deleteNode(String id) async {
    if (_secureStore != null) {
      final Map<dynamic, String> entries = await _entries();
      entries.remove(id);
      await _write(entries);
    } else {
      final HiveStorage<String> storage = _storage!;
      await storage.open();
      await storage.delete(id);
    }
  }

  Future<Map<dynamic, String>> _entries() async {
    if (_secureStore == null) {
      final HiveStorage<String> storage = _storage!;
      await storage.open();
      return storage.getAll();
    }
    final String? raw = await _secureStore.readString(_secureKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value.toString()),
        );
      }
    }
    final HiveStorage<String>? legacy = _storage;
    if (legacy == null) return <dynamic, String>{};
    await legacy.open();
    final Map<dynamic, String> migrated = legacy.getAll();
    if (migrated.isNotEmpty) {
      await _write(migrated);
      await legacy.clear();
    }
    return migrated;
  }

  Future<void> _write(Map<dynamic, String> entries) {
    return _secureStore!.writeString(_secureKey, jsonEncode(entries));
  }
}
