// lib/engine/si/si_engine_service.dart

import 'package:fantastic_guacamole/config/env.dart';
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

  Future<Map<String, dynamic>> generateResponse({
    required String input,
    required String message,
    String emotion = 'balanced',
    double confidence = 0.5,
    String? taskId,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    final bool aiProxyConfigured = Env.isAiProxyConfigured;
    final SIFinalOutputBundle output = await handleText(input);
    final String resolvedMessage = output.response.message.trim().isEmpty
        ? message
        : output.response.message;

    return <String, dynamic>{
      'input': input,
      'taskId': taskId,
      'message': resolvedMessage,
      'reasoning':
          context['reasoning']?.toString() ?? output.decision.reasoning,
      'emotion': output.response.emotion.isEmpty
          ? emotion
          : output.response.emotion,
      'confidence': output.response.confidence.clamp(0.0, 1.0),
      'generationMode': aiProxyConfigured ? 'proxy_llm' : 'deterministic_local',
      'isDeterministicLocal': !aiProxyConfigured,
      'engineDecision': output.decision.action,
    };
  }

  Map<String, dynamic> generateDecision({
    required String input,
    required Map<String, dynamic> context,
  }) {
    final String trimmed = input.trim();
    return <String, dynamic>{
      'action': trimmed.isEmpty ? 'idle' : 'respond',
      'input': input,
      'taskId': context['taskId']?.toString(),
      'intent': context['intent']?.toString() ?? 'general',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> updateMemory({
    required Map<String, dynamic>? currentState,
    required Map<String, dynamic> memoryEvent,
  }) {
    final List<Map<String, dynamic>> events =
        ((currentState?['memoryEvents'] as List?) ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
            .toList(growable: true);
    events.add(memoryEvent);

    return <String, dynamic>{
      ...?currentState,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'memoryEvents': events.length > 120
          ? events.sublist(events.length - 120)
          : events,
      'memoryEvent': memoryEvent,
    };
  }

  bool validateOutput({
    required String message,
    required double confidence,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
  }) {
    final String text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    if (confidence.isNaN || confidence < 0.3) {
      return false;
    }
    return coherent && deduped && policyAccepted && grounded;
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
