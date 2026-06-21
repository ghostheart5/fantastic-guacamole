import 'dart:async';

import 'si_engine.dart';

class SiController {
  SiController({SiEngine? engine}) : _engine = engine ?? const SiEngine();

  final SiEngine _engine;
  final StreamController<SiDecision> _decisionController = StreamController<SiDecision>.broadcast();

  List<SiTask> _tasks = const <SiTask>[];
  EnergyLevel _energy = EnergyLevel.medium;
  double _workload = 0.55;
  double _deadlinePressure = 0.4;
  String _latestInput = '';

  Stream<SiDecision> get decisions => _decisionController.stream;

  void initialize({
    List<SiTask> tasks = const <SiTask>[],
    EnergyLevel energy = EnergyLevel.medium,
    double workload = 0.55,
    double deadlinePressure = 0.4,
  }) {
    _tasks = List<SiTask>.from(tasks);
    _energy = energy;
    _workload = workload;
    _deadlinePressure = deadlinePressure;
    _emitDecision();
  }

  void updateTasks(List<SiTask> tasks) {
    _tasks = List<SiTask>.from(tasks);
    _emitDecision();
  }

  void updateEnergy(EnergyLevel level) {
    _energy = level;
    _emitDecision();
  }

  void updateWorkload(double value) {
    _workload = value.clamp(0.0, 1.0);
    _emitDecision();
  }

  void updateDeadlinePressure(double value) {
    _deadlinePressure = value.clamp(0.0, 1.0);
    _emitDecision();
  }

  void updateFromInput(String value) {
    _latestInput = value.trim();
    final String lower = _latestInput.toLowerCase();
    if (lower.contains('exhausted') || lower.contains('drained')) {
      _energy = EnergyLevel.low;
    } else if (lower.contains('focused') || lower.contains('energized')) {
      _energy = EnergyLevel.high;
    }
    if (lower.contains('deadline') || lower.contains('urgent')) {
      _deadlinePressure = 0.85;
    }
    _emitDecision();
  }

  void updateForTime(DateTime now) {
    final int hour = now.hour;
    if (hour < 7 || hour > 21) {
      _energy = EnergyLevel.low;
    } else if (hour < 11) {
      _energy = EnergyLevel.high;
    } else {
      _energy = EnergyLevel.medium;
    }
    _emitDecision();
  }

  void _emitDecision() {
    final UserSignalState state = UserSignalState(
      energyLevel: _energy,
      tasks: _tasks,
      workload: _workload,
      deadlinePressure: _deadlinePressure,
    );
    _decisionController.add(_engine.generateDecision(state));
  }

  void dispose() {
    _decisionController.close();
  }
}
