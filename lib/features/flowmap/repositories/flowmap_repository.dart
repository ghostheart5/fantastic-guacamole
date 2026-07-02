import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/features/flowmap/models/flowmap_node.dart';

class FlowmapRepository {
  FlowmapRepository({required this._storage});

  final HiveStorage<String> _storage;

  Future<List<FlowmapNode>> getNodes() async {
    await _storage.open();
    return _storage.getAll().values.map(FlowmapNode.fromRaw).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> saveNode(FlowmapNode node) async {
    await _storage.open();
    await _storage.put(node.id, node.toRaw());
  }

  Future<void> deleteNode(String id) async {
    await _storage.open();
    await _storage.delete(id);
  }
}
