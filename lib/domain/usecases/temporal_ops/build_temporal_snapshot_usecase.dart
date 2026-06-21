import '../../entities/event_node.dart';
import '../../entities/neural_heatmap_point.dart';
import '../../entities/temporal_block.dart';
import '../../entities/temporal_snapshot.dart';

class BuildTemporalSnapshotUseCase {
  TemporalSnapshot call({
    required DateTime anchorDate,
    required List<TemporalBlock> dayBlocks,
    required List<int> weekArc,
    required List<String> missionBlocks,
    required List<EventNode> eventNodes,
    required List<NeuralHeatmapPoint> heatmap,
  }) {
    return TemporalSnapshot(
      anchorDate: anchorDate,
      dayBlocks: dayBlocks,
      weekArc: weekArc,
      missionBlocks: missionBlocks,
      eventNodes: eventNodes,
      heatmap: heatmap,
    );
  }
}
