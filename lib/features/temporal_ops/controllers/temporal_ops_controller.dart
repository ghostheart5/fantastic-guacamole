import '../../../data/repositories/temporal_repository.dart';
import '../../../data/repositories/temporal_repository_impl.dart';
import '../../../domain/entities/event_node.dart';
import '../../../domain/entities/neural_heatmap_point.dart';
import '../../../domain/entities/temporal_block.dart';
import '../../../domain/usecases/temporal_ops/apply_focus_boost_usecase.dart';
import '../../../domain/usecases/temporal_ops/build_temporal_snapshot_usecase.dart';
import '../../../domain/usecases/temporal_ops/detect_time_fractures_usecase.dart';

class TemporalSnapshot {
  final DateTime anchorDate;
  final List<double> dayIntensity;
  final List<int> weekArc;
  final List<String> missionBlocks;
  final List<String> eventNodes;
  final List<double> neuralHeatmap;

  const TemporalSnapshot({
    required this.anchorDate,
    required this.dayIntensity,
    required this.weekArc,
    required this.missionBlocks,
    required this.eventNodes,
    required this.neuralHeatmap,
  });
}

class TemporalOpsController {
  TemporalOpsController({TemporalRepository? repository})
    : _repository = repository ?? TemporalRepositoryImpl(),
      _applyFocusBoostUseCase = ApplyFocusBoostUseCase(),
      _buildTemporalSnapshotUseCase = BuildTemporalSnapshotUseCase(),
      _detectTimeFracturesUseCase = DetectTimeFracturesUseCase();

  final TemporalRepository _repository;
  final ApplyFocusBoostUseCase _applyFocusBoostUseCase;
  final BuildTemporalSnapshotUseCase _buildTemporalSnapshotUseCase;
  final DetectTimeFracturesUseCase _detectTimeFracturesUseCase;

  DateTime warp(DateTime from, int days) {
    return from.add(Duration(days: days));
  }

  Future<TemporalSnapshot> snapshotFor(DateTime date) async {
    final List<double> baseDay = await dayIntensity();
    final List<int> baseWeek = await weekArc();
    final int seed = date.year * 10000 + date.month * 100 + date.day;

    final List<double> day = List<double>.generate(baseDay.length, (int i) {
      final double offset = (((seed + (i * 17)) % 22) - 11) / 100;
      return (baseDay[i] + offset).clamp(0.08, 0.98);
    });

    final List<int> week = List<int>.generate(baseWeek.length, (int i) {
      final int shift = ((seed + (i * 13)) % 3) - 1;
      final int value = baseWeek[i] + shift;
      return value.clamp(1, 7);
    });

    final List<String> missionBlocks = <String>[
      '${date.hour.toString().padLeft(2, '0')}:00 Focus Assault (90m) - Priority Alpha - Energy ${day.first.toStringAsFixed(2)}',
      '11:30 Tactical Review (45m) - Priority Bravo - Energy ${day[2].toStringAsFixed(2)}',
      '14:00 Execution Sweep (60m) - Priority Alpha - Energy ${day[4].toStringAsFixed(2)}',
    ];

    final List<String> eventNodes = <String>[
      '10:00 Standup Node - Locked',
      '13:30 Calendar Node - Conflict risk ${week[2] > 5 ? 'High' : 'Low'}',
      '16:00 Sync Node - Locked',
    ];

    final List<double> heatmap = List<double>.generate(35, (int i) {
      final double source = day[i % day.length];
      final double tweak = (((seed + (i * 29)) % 14) - 7) / 100;
      return (source + tweak).clamp(0.05, 1.0);
    });

    final _ = _buildTemporalSnapshotUseCase(
      anchorDate: date,
      dayBlocks: day
          .asMap()
          .entries
          .map(
            (MapEntry<int, double> entry) => TemporalBlock(
              label: 'H${entry.key + 1}',
              intensity: entry.value,
            ),
          )
          .toList(),
      weekArc: week,
      missionBlocks: missionBlocks,
      eventNodes: eventNodes
          .map(
            (String label) => EventNode(
              id: label,
              label: label,
              start: date,
              end: date.add(const Duration(minutes: 30)),
              locked: label.contains('Locked'),
            ),
          )
          .toList(),
      heatmap: heatmap
          .asMap()
          .entries
          .map(
            (MapEntry<int, double> entry) =>
                NeuralHeatmapPoint(index: entry.key, load: entry.value),
          )
          .toList(),
    );

    return TemporalSnapshot(
      anchorDate: date,
      dayIntensity: day,
      weekArc: week,
      missionBlocks: missionBlocks,
      eventNodes: eventNodes,
      neuralHeatmap: heatmap,
    );
  }

  Future<List<double>> dayIntensity() => _repository.loadDayIntensity();
  Future<List<int>> weekArc() => _repository.loadWeekArc();

  double averageIntensity(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  int monthlyProjection(List<int> weekly) {
    if (weekly.isEmpty) {
      return 0;
    }
    return weekly.reduce((int a, int b) => a + b) * 4;
  }

  List<double> applyFocusBoost(List<double> values, double boost) {
    return _applyFocusBoostUseCase(values, boost);
  }

  bool isTimeFracture({
    required List<double> dayValues,
    required double boost,
    required int overloadedNodes,
  }) {
    return _detectTimeFracturesUseCase(
      focusScore: averageIntensity(dayValues),
      overloadedNodes: overloadedNodes,
      boost: boost,
    );
  }
}
