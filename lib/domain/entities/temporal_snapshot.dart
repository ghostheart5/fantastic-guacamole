import 'event_node.dart';
import 'neural_heatmap_point.dart';
import 'temporal_block.dart';

class TemporalSnapshot {
  final DateTime anchorDate;
  final List<TemporalBlock> dayBlocks;
  final List<int> weekArc;
  final List<String> missionBlocks;
  final List<EventNode> eventNodes;
  final List<NeuralHeatmapPoint> heatmap;

  const TemporalSnapshot({
    required this.anchorDate,
    required this.dayBlocks,
    required this.weekArc,
    required this.missionBlocks,
    required this.eventNodes,
    required this.heatmap,
  });
}
