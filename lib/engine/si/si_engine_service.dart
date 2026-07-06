// lib/engine/si/si_engine_service.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';

class SIEngineService {
  SIEngineService({
    SIEngine? engine,
    SIEngineRuntimeState initialRuntime = const SIEngineRuntimeState(),
  }) : _engine = engine ?? SIEngine(),
       _runtime = initialRuntime;

  final SIEngine _engine;
  SIEngineRuntimeState _runtime;

  SIEngineRuntimeState get runtime => _runtime;
  SIMemoryStore get memory => _runtime.memory;

  Future<SIFinalOutputBundle> handleUserInput(
    SIInputPacket input, {
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
    SIEngineRuntimeState? runtime,
  }) async {
    final SIFinalOutputBundle output = await _engine.process(
      input: input,
      runtime: runtime ?? _runtime,
      history: history,
      task: task,
      goals: goals,
      previousMood: previousMood,
    );

    _runtime = output.runtime;
    return output;
  }

  Future<SIFinalOutputBundle> handleText(
    String text, {
    List<String> conversationHistory = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> context = const <String, dynamic>{},
    SILatentInputs latent = const SILatentInputs(),
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
  }) {
    return handleUserInput(
      SIInputPacket(
        text: text,
        history: conversationHistory,
        metadata: metadata,
        context: context,
        latent: latent,
      ),
      history: history,
      task: task,
      goals: goals,
      previousMood: previousMood,
    );
  }

  void replaceRuntime(SIEngineRuntimeState runtime) {
    _runtime = runtime;
  }

  void replaceMemory(SIMemoryStore memory) {
    _runtime = _runtime.copyWith(memory: memory);
  }

  void clear() {
    _runtime = const SIEngineRuntimeState();
  }
}
