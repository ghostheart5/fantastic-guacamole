// lib/engine/si/si_ai_service.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_engine_service.dart';
import 'package:fantastic_guacamole/engine/si/si_output_bundle.dart';

class SIAIService {
  SIAIService({SIEngineService? engineService})
    : _engineService = engineService ?? SIEngineService();

  final SIEngineService _engineService;

  SIMemoryStore get memory => _engineService.memory;

  Future<AIResponse> send(
    SIInputPacket input, {
    SIMemoryStore? memory,
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    String? previousMood,
  }) async {
    final SIOutputBundle bundle = await process(
      input,
      memory: memory,
      history: history,
      task: task,
      previousMood: previousMood,
    );
    return AIResponse.fromBundle(bundle);
  }

  Future<SIOutputBundle> process(
    SIInputPacket input, {
    SIMemoryStore? memory,
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    String? previousMood,
  }) async {
    final SIEngineRuntimeState? runtime = memory == null
        ? null
        : _engineService.runtime.copyWith(memory: memory);
    final SIFinalOutputBundle output = await _engineService.handleUserInput(
      input,
      history: history,
      task: task,
      previousMood: previousMood,
      runtime: runtime,
    );
    return output.core;
  }

  Future<AIResponse> sendText(
    String text, {
    List<String> history = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> context = const <String, dynamic>{},
    SILatentInputs latent = const SILatentInputs(),
    Task? task,
  }) {
    return send(
      SIInputPacket(
        text: text,
        history: history,
        metadata: metadata,
        context: context,
        latent: latent,
      ),
      task: task,
    );
  }

  void replaceMemory(SIMemoryStore memory) {
    _engineService.replaceMemory(memory);
  }

  void clearMemory() {
    _engineService.clear();
  }

  Future<AIResponse> handleInput(
    String prompt, {
    required List<Task> tasks,
    required double energy,
    required LearningState learning,
    required AIPersonality personality,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    return sendText(
      prompt,
      history: history
          .map((Map<String, String> item) => item['content'] ?? '')
          .where((String value) => value.trim().isNotEmpty)
          .toList(growable: false),
      context: <String, dynamic>{
        ...context,
        'energy': energy,
        'completedToday': learning.completed,
        'skipped': learning.skipped,
        'personality': personality.name,
        'taskCount': tasks.length,
      },
      task: tasks.isEmpty ? null : tasks.first,
    );
  }

  Future<AIResponse> generate({
    required List<Task> tasks,
    required SIState si,
    required LearningState learning,
    required AIPersonality personality,
  }) {
    return handleInput(
      'Provide one grounded recommendation.',
      tasks: tasks,
      energy: si.energy,
      learning: learning,
      personality: personality,
      context: <String, dynamic>{'mode': 'fallback_generate'},
    );
  }
}
