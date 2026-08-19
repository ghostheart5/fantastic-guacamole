import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/si_engine_service.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';

class StateSiEngineService {
  StateSiEngineService(
    this._repository, {
    required this.dependencies,
    SIEngineService? engine,
  }) : _engine = engine ?? SIEngineService();

  final SiEngineRepository _repository;
  final SIEngineService _engine;
  final SiEngineDependencies dependencies;

  Future<Map<String, dynamic>?> loadState() => _repository.loadState();

  Future<void> saveState(Map<String, dynamic> state) =>
      _repository.saveState(state);

  Future<Map<String, dynamic>?> exportState() => _repository.exportState();

  Future<void> clearMemory() async {
    _engine.clear();
    await _repository.clearState();
  }

  Future<SIFinalOutputBundle> handleUserInput(
    SIInputPacket input, {
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
  }) {
    return _engine.handleUserInput(
      input,
      history: history,
      task: task,
      goals: goals,
      previousMood: previousMood,
    );
  }

  Future<Map<String, dynamic>> generateResponse({
    required String input,
    required String message,
    String emotion = 'balanced',
    double confidence = 0.5,
    String? taskId,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    return _engine.generateResponse(
      input: input,
      message: message,
      emotion: emotion,
      confidence: confidence,
      taskId: taskId,
      context: context,
    );
  }

  Map<String, dynamic> updateMemory({
    required Map<String, dynamic>? currentState,
    required Map<String, dynamic> memoryEvent,
  }) {
    return _engine.updateMemory(
      currentState: currentState,
      memoryEvent: memoryEvent,
    );
  }

  bool validateOutput({
    required String message,
    required double confidence,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
  }) {
    return _engine.validateOutput(
      message: message,
      confidence: confidence,
      coherent: coherent,
      deduped: deduped,
      policyAccepted: policyAccepted,
      grounded: grounded,
    );
  }
}
