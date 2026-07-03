// Module 1 — Core Orchestrator
// Runs the full pipeline in order:
//   Input → UserState → Intent → Instinct → Reasoning → Decision → Response → Memory Update

import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/core/si_decision_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_input_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_instinct_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_intent_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_memory_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_reasoning_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_response_module.dart';

export 'package:fantastic_guacamole/engine/si/core/si_decision_module.dart'
    show SIDecision, EthicsAssessment, SIDecisionPolicy;
export 'package:fantastic_guacamole/engine/si/core/si_input_module.dart'
    show SIContext, SIInputPacket, SILatentInputs, SINonTextInputs, SIUserState;
export 'package:fantastic_guacamole/engine/si/core/si_instinct_module.dart'
    show InstinctGuidance;
export 'package:fantastic_guacamole/engine/si/core/si_intent_module.dart'
    show IntentCandidate, SIIntent;
export 'package:fantastic_guacamole/engine/si/core/si_memory_module.dart'
    show
        MemoryRecord,
        MemoryTier,
        SIMemoryModule,
        SIMemoryStore,
        SIMemoryUpdate,
        SISnapshot,
        SITieredMemory;
export 'package:fantastic_guacamole/engine/si/core/si_reasoning_module.dart'
    show AgentNote, MetaReasoning, ReasoningTrace, SICognitionState, SIPrediction;
export 'package:fantastic_guacamole/engine/si/core/si_response_module.dart'
    show EmotionalSignal, PersonalityTraits, SIPersona, SIResponse;

// ─── Full pipeline result ─────────────────────────────────────────────────────

class SIPipelineResult {
  const SIPipelineResult({
    required this.context,
    required this.intent,
    required this.instinct,
    required this.cognition,
    required this.decision,
    required this.response,
    required this.memoryUpdate,
  });

  final SIContext context;
  final SIIntent intent;
  final InstinctGuidance instinct;
  final SICognitionState cognition;
  final SIDecision decision;
  final SIResponse response;
  final SIMemoryUpdate memoryUpdate;
}

// ─── Orchestrator ─────────────────────────────────────────────────────────────

class SICore {
  SICore({
    SIMemoryStore? memory,
    SIDecisionPolicy? policy,
  })  : _memory = memory ?? const SIMemoryStore(),
        _input = const SIInputModule(),
        _intent = const SIIntentModule(),
        _instinct = const SIInstinctModule(),
        _reasoning = const SIReasoningModule(),
        _decision = SIDecisionModule(policy: policy ?? const SIDecisionPolicy()),
        _response = const SIResponseModule(),
        _memoryModule = const SIMemoryModule();

  SIMemoryStore _memory;

  final SIInputModule _input;
  final SIIntentModule _intent;
  final SIInstinctModule _instinct;
  final SIReasoningModule _reasoning;
  final SIDecisionModule _decision;
  final SIResponseModule _response;
  final SIMemoryModule _memoryModule;

  SIMemoryStore get memory => _memory;

  // ── Pipeline ──────────────────────────────────────────────────────────────

  SIPipelineResult run({
    required SIInputPacket input,
    String mood = 'neutral',
    Task? task,
    List<NeuralEntry> history = const <NeuralEntry>[],
    double energy = 1.0,
    double fatigue = 0.0,
    int completed = 0,
    int skipped = 0,
  }) {
    // Step 1 — Input → SIContext
    final SIContext context = _input.process(input, mood: mood);

    // Step 2 — Intent
    final SIIntent intent = _intent.extract(input.text);

    // Step 3 — Instinct (hard constraint layer — established before reasoning)
    final InstinctGuidance instinct = _instinct.evaluate(
      mood: context.userState.emotion,
      anticipatesConfusion: intent.isComplex,
      confidence: intent.confidence,
    );

    // Step 4 — Reasoning
    final SICognitionState cognition = _reasoning.process(
      intent: intent.primary.label,
      mood: context.userState.emotion,
      input: input.text,
      anticipatesConfusion: intent.isComplex,
      confidence: intent.confidence,
      history: history,
      task: task?.title ?? '',
    );

    // Step 5 — Decision (constrained by instinct)
    final SIDecision decision = _decision.make(
      intent: intent.primary.label,
      reply: cognition.summary,
      mood: context.userState.emotion,
      simplify: instinct.avoidOverwhelm,
      score: intent.confidence,
      task: task,
    );

    // Step 6 — Response (shaped by instinct + decision)
    final SIResponse response = _response.generate(
      intent: intent.primary.label,
      mood: context.userState.emotion,
      reasoning: decision.reasoning,
      confidence: decision.score,
      safetyFirst: instinct.safetyFirst,
      avoidOverwhelm: instinct.avoidOverwhelm,
      latent: input.latent,
      task: task,
      previousMood: _memory.latest?.reasoning,
    );

    // Step 7 — Memory update
    final SIMemoryUpdate memUpdate = _memoryModule.update(
      current: _memory,
      energy: energy,
      fatigue: fatigue,
      completed: completed,
      skipped: skipped,
      taskId: task?.id.toString(),
      reasoning: cognition.summary,
    );

    _memory = memUpdate.store;

    return SIPipelineResult(
      context: context,
      intent: intent,
      instinct: instinct,
      cognition: cognition,
      decision: decision,
      response: response,
      memoryUpdate: memUpdate,
    );
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  String quickResponse({
    required String text,
    String mood = 'neutral',
    Task? task,
  }) {
    final SIPipelineResult result = run(
      input: SIInputPacket(text: text),
      mood: mood,
      task: task,
    );
    return result.response.message;
  }

  Map<String, dynamic> snapshot() => <String, dynamic>{
    'memory_count': _memory.snapshots.length,
    'short_term_records': _memory.tiered.shortTerm.length,
    'mid_term_records': _memory.tiered.midTerm.length,
    'long_term_records': _memory.tiered.longTerm.length,
  };
}
