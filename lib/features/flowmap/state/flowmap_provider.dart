import 'package:fantastic_guacamole/features/flowmap/models/flowmap_node.dart';
import 'package:fantastic_guacamole/state/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flowmapProvider = NotifierProvider<FlowmapController, AsyncValue<List<FlowmapNode>>>(
  FlowmapController.new,
);

class FlowmapController extends Notifier<AsyncValue<List<FlowmapNode>>> {
  @override
  AsyncValue<List<FlowmapNode>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final nodes = await ref.read(flowmapServiceProvider).getNodes();
      state = AsyncValue.data(nodes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addNode({
    required String title,
    String? description,
    List<String> tags = const [],
  }) async {
    final String? trimmedDescription = description?.trim();
    final node = FlowmapNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      description: (trimmedDescription?.isEmpty ?? true) ? null : trimmedDescription,
      tags: tags,
      createdAt: DateTime.now(),
    );
    await ref.read(flowmapServiceProvider).saveNode(node);
    state = AsyncValue.data([...state.asData?.value ?? <FlowmapNode>[], node]);
  }

  Future<void> deleteNode(String id) async {
    await ref.read(flowmapServiceProvider).deleteNode(id);
    final updated = (state.asData?.value ?? <FlowmapNode>[]).where((n) => n.id != id).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> updateNode(FlowmapNode updated) async {
    await ref.read(flowmapServiceProvider).saveNode(updated);
    state = AsyncValue.data([
      for (final n in state.asData?.value ?? <FlowmapNode>[])
        if (n.id == updated.id) updated else n,
    ]);
  }
}
