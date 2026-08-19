import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/core/si_core.dart';
import 'package:fantastic_guacamole/engine/si/core/si_memory_module.dart';
import 'package:fantastic_guacamole/engine/si/si_output_bundle.dart';
import 'package:fantastic_guacamole/engine/si/si_output_validator.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';

typedef SIClock = DateTime Function();

class SIEngineRuntimeState {
  const SIEngineRuntimeState({this.memory = const SIMemoryStore()});

  final SIMemoryStore memory;

  SIEngineRuntimeState copyWith({SIMemoryStore? memory}) {
    return SIEngineRuntimeState(memory: memory ?? this.memory);
  }
}

class SIProvenance {
  const SIProvenance({
    required this.decisionId,
    required this.modelVersion,
    required this.generatedAt,
    required this.evidenceSources,
    required this.generationMode,
    required this.validationViolations,
  });

  final String decisionId;
  final String modelVersion;
  final DateTime generatedAt;
  final List<String> evidenceSources;
  final String generationMode;
  final List<String> validationViolations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'decisionId': decisionId,
    'modelVersion': modelVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'evidenceSources': evidenceSources,
    'generationMode': generationMode,
    'validationViolations': validationViolations,
  };
}

class SIFinalOutputBundle {
  const SIFinalOutputBundle({
    required this.core,
    required this.runtime,
    required this.provenance,
    required this.debugTrace,
  });

  final SIOutputBundle core;
  final SIEngineRuntimeState runtime;
  final SIProvenance provenance;
  final SIDebugTrace debugTrace;

  SIResponse get response => core.response;
  SIDecision get decision => core.decision;
  SIMemoryStore get memory => runtime.memory;
  String get message => response.message;
}

/// Behavior-first engine: one core pipeline followed by one terminal gate.
class SIEngine {
  SIEngine({SIOutputValidator? validator, SIClock? clock})
    : validator = validator ?? const SIOutputValidator(),
      _clock = clock ?? DateTime.now;

  static const String modelVersion = 'si-core-v1';

  final SIOutputValidator validator;
  final SIClock _clock;
  final SIMemoryModule _memoryModule = const SIMemoryModule();

  Future<SIFinalOutputBundle> process({
    required SIInputPacket input,
    SIEngineRuntimeState runtime = const SIEngineRuntimeState(),
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
  }) async {
    final DateTime generatedAt = _clock().toUtc();
    try {
      final SICore core = SICore(memory: runtime.memory);
      final SIPipelineResult result = core.run(
        input: input,
        mood: previousMood ?? 'neutral',
        task: task,
        history: history,
        energy: 1 - input.latent.frustration,
        fatigue: input.latent.hesitation,
        completed: _intValue(input.metadata['completed']),
        skipped: _intValue(input.metadata['skipped']),
      );
      final SIResponse candidate = _shapeForContext(input, result.response);
      final bool deduped = !isSubstantiallyRepeatedResponse(
        message: candidate.message,
        recentResponseHashes: const <String>[],
        recentResponseSummaries: input.history,
      );
      final SIOutputValidationResult validation = validator.validate(
        response: candidate,
        decision: result.decision,
        deduped: deduped,
      );

      // Discard the core's provisional memory and persist only validated output.
      final SIMemoryUpdate memory = _memoryModule.update(
        current: runtime.memory,
        context: result.context,
        decision: result.decision,
        response: validation.response,
      );
      final SIDebugTrace trace = SIDebugTrace(
        events: const <String>[
          'pipeline_start',
          'terminal_validation',
          'complete',
        ],
        warnings: validation.violations,
        metadata: <String, dynamic>{
          'intent': result.intent.primary.label,
          'validationAccepted': validation.accepted,
        },
      );
      final SIOutputBundle output = SIOutputBundle(
        context: result.context,
        intent: result.intent,
        instinct: result.instinct,
        cognition: result.cognition,
        decision: result.decision,
        response: validation.response,
        memory: memory,
        debugTrace: trace,
      );
      return _bundle(
        output: output,
        runtime: runtime.copyWith(memory: memory.store),
        input: input,
        task: task,
        goals: goals,
        history: history,
        generatedAt: generatedAt,
        violations: validation.violations,
      );
    } catch (error) {
      return _fallback(
        input: input,
        runtime: runtime,
        task: task,
        goals: goals,
        history: history,
        generatedAt: generatedAt,
        error: error,
      );
    }
  }

  SIFinalOutputBundle _fallback({
    required SIInputPacket input,
    required SIEngineRuntimeState runtime,
    required Task? task,
    required List<String> goals,
    required List<NeuralEntry> history,
    required DateTime generatedAt,
    required Object error,
  }) {
    final SIPipelineResult result = SICore(memory: runtime.memory).run(
      input: const SIInputPacket(
        text: 'Provide one safe and grounded next step.',
      ),
      task: task,
    );
    final SIResponse response = SIResponse(
      message:
          'I hit a system issue. Tell me the task or goal, and I will help with one small next step.',
      emotion: 'balanced',
      persona: result.response.persona,
      traits: result.response.traits,
      confidence: 0.5,
      task: task,
    );
    final SIMemoryUpdate memory = _memoryModule.update(
      current: runtime.memory,
      context: result.context,
      decision: result.decision,
      response: response,
    );
    final SIDebugTrace trace = SIDebugTrace(
      events: const <String>[
        'pipeline_start',
        'fallback_validation',
        'complete',
      ],
      warnings: <String>['engine_error:${error.runtimeType}'],
      metadata: const <String, dynamic>{'validationAccepted': true},
    );
    final SIOutputBundle output = SIOutputBundle(
      context: result.context,
      intent: result.intent,
      instinct: result.instinct,
      cognition: result.cognition,
      decision: result.decision,
      response: response,
      memory: memory,
      debugTrace: trace,
    );
    return _bundle(
      output: output,
      runtime: runtime.copyWith(memory: memory.store),
      input: input,
      task: task,
      goals: goals,
      history: history,
      generatedAt: generatedAt,
      violations: <String>['engine_error:${error.runtimeType}'],
    );
  }

  SIFinalOutputBundle _bundle({
    required SIOutputBundle output,
    required SIEngineRuntimeState runtime,
    required SIInputPacket input,
    required Task? task,
    required List<String> goals,
    required List<NeuralEntry> history,
    required DateTime generatedAt,
    required List<String> violations,
  }) {
    final List<String> sources = <String>[
      'user_input',
      if (input.history.isNotEmpty) 'conversation_history',
      if (history.isNotEmpty) 'learning_history',
      if (task != null) 'task:${task.id}',
      if (goals.isNotEmpty) 'goals',
      ...input.context.keys.map((String key) => 'context:$key'),
      ...input.metadata.keys.map((String key) => 'metadata:$key'),
    ];
    final List<String> evidence = sources.toSet().toList()..sort();
    final String decisionId = _stableId(
      <String>[
        modelVersion,
        input.text.trim(),
        output.intent.primary.label,
        output.decision.action,
        output.decision.reasoning,
        output.response.message,
        ...evidence,
      ].join('|'),
    );
    return SIFinalOutputBundle(
      core: output,
      runtime: runtime,
      provenance: SIProvenance(
        decisionId: decisionId,
        modelVersion: modelVersion,
        generatedAt: generatedAt,
        evidenceSources: List<String>.unmodifiable(evidence),
        generationMode: 'deterministic_local',
        validationViolations: List<String>.unmodifiable(violations),
      ),
      debugTrace: output.debugTrace,
    );
  }

  int _intValue(Object? value) => value is num ? value.toInt() : 0;

  SIResponse _shapeForContext(SIInputPacket input, SIResponse response) {
    final String mode = input.context['mode']?.toString() ?? '';
    if (mode != 'system_console' ||
        response.message.toLowerCase().contains('action')) {
      return response;
    }
    return SIResponse(
      message: 'Next action: ${response.message}',
      emotion: response.emotion,
      persona: response.persona,
      traits: response.traits,
      confidence: response.confidence,
      task: response.task,
    );
  }

  String _stableId(String value) {
    int hash = 0x811c9dc5;
    for (final int unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'si-${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
