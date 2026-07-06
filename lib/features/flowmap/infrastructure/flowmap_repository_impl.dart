import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart' as legacy;
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_edge_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_graph_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_node_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';

class FlowmapRepositoryImpl implements FlowmapRepository {
  const FlowmapRepositoryImpl(this._legacyRepository);

  final IFlowmapRepository _legacyRepository;

  @override
  Future<FlowmapGraphEntity> getFlowmap() async {
    final List<legacy.FlowmapNode> nodes = await _legacyRepository.getNodes();
    final List<FlowmapNodeEntity> mappedNodes = nodes.map(_toNodeEntity).toList();

    final Set<String> seenEdges = <String>{};
    final List<FlowmapEdgeEntity> edges = <FlowmapEdgeEntity>[];
    for (final legacy.FlowmapNode node in nodes) {
      for (final String targetId in node.connectedTo) {
        final FlowmapEdgeEntity edge = FlowmapEdgeEntity(fromNodeId: node.id, toNodeId: targetId);
        if (seenEdges.add(edge.id)) {
          edges.add(edge);
        }
      }
    }

    return FlowmapGraphEntity(nodes: mappedNodes, edges: edges);
  }

  @override
  Future<void> saveFlowmap(FlowmapGraphEntity graph) async {
    final Map<String, Set<String>> outgoing = <String, Set<String>>{
      for (final FlowmapNodeEntity node in graph.nodes) node.id: <String>{},
    };

    for (final FlowmapEdgeEntity edge in graph.edges) {
      outgoing.putIfAbsent(edge.fromNodeId, () => <String>{}).add(edge.toNodeId);
    }

    final List<legacy.FlowmapNode> nodes = graph.nodes
        .map(
          (FlowmapNodeEntity node) => legacy.FlowmapNode(
            id: node.id,
            title: node.title,
            description: node.description,
            tags: node.tags,
            connectedTo: (outgoing[node.id] ?? <String>{}).toList()..sort(),
            createdAt: node.createdAt ?? DateTime.now(),
          ),
        )
        .toList();

    await _legacyRepository.saveNodes(nodes);
  }

  @override
  Future<void> clearFlowmap() {
    return _legacyRepository.saveNodes(const <legacy.FlowmapNode>[]);
  }

  @override
  Future<void> addNode(FlowmapNodeEntity node) {
    return _legacyRepository.saveNode(_toLegacyNode(node));
  }

  @override
  Future<void> addEdge(FlowmapEdgeEntity edge) async {
    final List<legacy.FlowmapNode> nodes = await _legacyRepository.getNodes();
    final int fromIndex = nodes.indexWhere((legacy.FlowmapNode node) => node.id == edge.fromNodeId);
    final bool toExists = nodes.any((legacy.FlowmapNode node) => node.id == edge.toNodeId);

    if (fromIndex < 0 || !toExists) {
      throw StateError('Cannot add edge for unknown node ids: ${edge.id}');
    }

    final legacy.FlowmapNode from = nodes[fromIndex];
    final Set<String> updatedConnections = <String>{...from.connectedTo, edge.toNodeId};
    await _legacyRepository.saveNode(
      from.copyWith(connectedTo: updatedConnections.toList()..sort()),
    );
  }

  static FlowmapNodeEntity _toNodeEntity(legacy.FlowmapNode node) {
    return FlowmapNodeEntity(
      id: node.id,
      title: node.title,
      description: node.description,
      tags: node.tags,
      createdAt: node.createdAt,
    );
  }

  static legacy.FlowmapNode _toLegacyNode(FlowmapNodeEntity node) {
    return legacy.FlowmapNode(
      id: node.id,
      title: node.title,
      description: node.description,
      tags: node.tags,
      connectedTo: const <String>[],
      createdAt: node.createdAt ?? DateTime.now(),
    );
  }
}
