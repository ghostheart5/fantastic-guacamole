// lib/engine/si/si_engine.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/core/si_decision_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_input_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_instinct_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_intent_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_memory_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_reasoning_module.dart';
import 'package:fantastic_guacamole/engine/si/core/si_response_module.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/si/prediction_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_dissonance_resolver.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_evolution_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_entropy_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_evolution_timeline.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_harmonics_system.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_law_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_phase_shift_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_self_repair_system.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_style_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_contextual_gravity.dart';
import 'package:fantastic_guacamole/engine/si/si_emotion_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_output_bundle.dart';
import 'package:fantastic_guacamole/engine/si/si_personality_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_presence_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_self_consistency_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_continuity_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_curiosity.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_instinct_system.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_intuition.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_language_generator.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_memory_echo_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_memory_fabric.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_memory_topology.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_memory_weather_system.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_meta_emotion_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_temporal_awareness_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_user_narrative_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_user_state_engine.dart';

class SIEngineRuntimeState {
  const SIEngineRuntimeState({
    this.memory = const SIMemoryStore(),
    this.ecosystem = const SIEcosystemState(),
    this.timeline = const EvolutionTimeline(),
    this.topology = const MemoryTopology(),
    this.learning = const AdaptiveLearningWeights(),
    this.narrative,
    this.phase,
  });

  final SIMemoryStore memory;
  final SIEcosystemState ecosystem;
  final EvolutionTimeline timeline;
  final MemoryTopology topology;
  final AdaptiveLearningWeights learning;
  final UserNarrative? narrative;
  final SIPhase? phase;

  SIEngineRuntimeState copyWith({
    SIMemoryStore? memory,
    SIEcosystemState? ecosystem,
    EvolutionTimeline? timeline,
    MemoryTopology? topology,
    AdaptiveLearningWeights? learning,
    UserNarrative? narrative,
    SIPhase? phase,
  }) {
    return SIEngineRuntimeState(
      memory: memory ?? this.memory,
      ecosystem: ecosystem ?? this.ecosystem,
      timeline: timeline ?? this.timeline,
      topology: topology ?? this.topology,
      learning: learning ?? this.learning,
      narrative: narrative ?? this.narrative,
      phase: phase ?? this.phase,
    );
  }
}

class SIFinalOutputBundle {
  const SIFinalOutputBundle({
    required this.core,
    required this.runtime,
    required this.patterns,
    required this.learning,
    required this.temporal,
    required this.continuity,
    required this.narrative,
    required this.attention,
    required this.intuition,
    required this.curiosity,
    required this.debugTrace,
  });

  final SIOutputBundle core;
  final SIEngineRuntimeState runtime;
  final MicroPatternReport patterns;
  final AdaptiveLearningUpdate learning;
  final TemporalAwarenessReport temporal;
  final ContinuityProfile continuity;
  final UserNarrativeResult narrative;
  final AttentionProfile attention;
  final SyntheticIntuitionResult intuition;
  final SyntheticCuriosityResult curiosity;
  final SIDebugTrace debugTrace;

  SIResponse get response => core.response;
  SIDecision get decision => core.decision;
  SIMemoryStore get memory => runtime.memory;
  String get message => response.message;
}

class SIEngine {
  SIEngine({
    SIInputModule? inputModule,
    SIIntentModule? intentModule,
    SIInstinctModule? instinctModule,
    SIReasoningModule? reasoningModule,
    SIDecisionModule? decisionModule,
    SIResponseModule? responseModule,
    SIMemoryModule? memoryModule,
    PredictionEngine? predictionEngine,
    SISyntheticMemoryFabric? memoryFabric,
    SISyntheticMemoryTopology? memoryTopology,
    SISyntheticMemoryEchoLayer? memoryEcho,
    SISyntheticMemoryWeatherSystem? memoryWeather,
    SISyntheticContinuityEngine? continuityEngine,
    SITemporalAwarenessEngine? temporalEngine,
    SICognitiveMicroPatternEngine? patternEngine,
    SIAdaptiveLearning? adaptiveLearning,
    SIUserStateEngine? userStateEngine,
    SICognitiveEcosystemLayer? ecosystemLayer,
    SICognitiveEcosystemEvolutionEngine? ecosystemEvolution,
    SICognitiveEvolutionTimelineEngine? evolutionTimeline,
    SICognitiveLoadBalancer? loadBalancer,
    SICognitiveEntropyController? entropyController,
    SICognitiveResonanceEngine? resonanceEngine,
    SICognitiveTemperatureController? temperatureController,
    SICognitivePhaseShiftEngine? phaseShiftEngine,
    SIContextualGravity? contextualGravity,
    SISyntheticAttentionSystem? attentionSystem,
    SISyntheticInstinctSystem? syntheticInstinct,
    SISyntheticIntuition? syntheticIntuition,
    SISyntheticLanguageGenerator? languageGenerator,
    SISyntheticMetaEmotionEngine? metaEmotionEngine,
    SISyntheticCuriosity? curiosityEngine,
    SICognitiveLawEngine? lawEngine,
    SICognitiveDissonanceResolver? dissonanceResolver,
    SISelfConsistencyEngine? consistencyEngine,
    SICognitiveSelfRepairSystem? selfRepairSystem,
    SICognitiveStyleEngine? styleEngine,
    SIPresenceEngine? presenceEngine,
    SIPersonalityEngine? personalityEngine,
    SIEmotionEngine? emotionEngine,
    UserNarrativeEngine? narrativeEngine,
    SICognitiveHarmonicsSystem? harmonicsSystem,
  }) : inputModule = inputModule ?? const SIInputModule(),
       intentModule = intentModule ?? const SIIntentModule(),
       instinctModule = instinctModule ?? const SIInstinctModule(),
       predictionEngine = predictionEngine ?? const PredictionEngine(),
       decisionModule = decisionModule ?? const SIDecisionModule(),
       responseModule = responseModule ?? const SIResponseModule(),
       memoryModule = memoryModule ?? const SIMemoryModule(),
       memoryFabric = memoryFabric ?? const SISyntheticMemoryFabric(),
       memoryTopology = memoryTopology ?? const SISyntheticMemoryTopology(),
       memoryEcho = memoryEcho ?? const SISyntheticMemoryEchoLayer(),
       memoryWeather = memoryWeather ?? const SISyntheticMemoryWeatherSystem(),
       continuityEngine =
           continuityEngine ?? const SISyntheticContinuityEngine(),
       temporalEngine = temporalEngine ?? const SITemporalAwarenessEngine(),
       patternEngine = patternEngine ?? const SICognitiveMicroPatternEngine(),
       adaptiveLearning = adaptiveLearning ?? const SIAdaptiveLearning(),
       userStateEngine = userStateEngine ?? const SIUserStateEngine(),
       ecosystemLayer = ecosystemLayer ?? const SICognitiveEcosystemLayer(),
       ecosystemEvolution =
           ecosystemEvolution ?? const SICognitiveEcosystemEvolutionEngine(),
       evolutionTimeline =
           evolutionTimeline ?? const SICognitiveEvolutionTimelineEngine(),
       loadBalancer = loadBalancer ?? const SICognitiveLoadBalancer(),
       entropyController =
           entropyController ?? const SICognitiveEntropyController(),
       resonanceEngine = resonanceEngine ?? const SICognitiveResonanceEngine(),
       temperatureController =
           temperatureController ?? const SICognitiveTemperatureController(),
       phaseShiftEngine =
           phaseShiftEngine ?? const SICognitivePhaseShiftEngine(),
       contextualGravity = contextualGravity ?? const SIContextualGravity(),
       attentionSystem = attentionSystem ?? const SISyntheticAttentionSystem(),
       syntheticInstinct =
           syntheticInstinct ?? const SISyntheticInstinctSystem(),
       syntheticIntuition = syntheticIntuition ?? const SISyntheticIntuition(),
       languageGenerator =
           languageGenerator ?? const SISyntheticLanguageGenerator(),
       metaEmotionEngine =
           metaEmotionEngine ?? const SISyntheticMetaEmotionEngine(),
       curiosityEngine = curiosityEngine ?? const SISyntheticCuriosity(),
       lawEngine = lawEngine ?? const SICognitiveLawEngine(),
       dissonanceResolver =
           dissonanceResolver ?? const SICognitiveDissonanceResolver(),
       consistencyEngine = consistencyEngine ?? const SISelfConsistencyEngine(),
       selfRepairSystem =
           selfRepairSystem ?? const SICognitiveSelfRepairSystem(),
       styleEngine = styleEngine ?? const SICognitiveStyleEngine(),
       presenceEngine = presenceEngine ?? const SIPresenceEngine(),
       personalityEngine = personalityEngine ?? const SIPersonalityEngine(),
       emotionEngine = emotionEngine ?? const SIEmotionEngine(),
       narrativeEngine = narrativeEngine ?? const UserNarrativeEngine(),
       harmonicsSystem = harmonicsSystem ?? const SICognitiveHarmonicsSystem() {
    this.reasoningModule =
        reasoningModule ??
        SIReasoningModule(predictionEngine: this.predictionEngine);
  }

  final SIInputModule inputModule;
  final SIIntentModule intentModule;
  final SIInstinctModule instinctModule;
  late final SIReasoningModule reasoningModule;
  final SIDecisionModule decisionModule;
  final SIResponseModule responseModule;
  final SIMemoryModule memoryModule;
  final PredictionEngine predictionEngine;
  final SISyntheticMemoryFabric memoryFabric;
  final SISyntheticMemoryTopology memoryTopology;
  final SISyntheticMemoryEchoLayer memoryEcho;
  final SISyntheticMemoryWeatherSystem memoryWeather;
  final SISyntheticContinuityEngine continuityEngine;
  final SITemporalAwarenessEngine temporalEngine;
  final SICognitiveMicroPatternEngine patternEngine;
  final SIAdaptiveLearning adaptiveLearning;
  final SIUserStateEngine userStateEngine;
  final SICognitiveEcosystemLayer ecosystemLayer;
  final SICognitiveEcosystemEvolutionEngine ecosystemEvolution;
  final SICognitiveEvolutionTimelineEngine evolutionTimeline;
  final SICognitiveLoadBalancer loadBalancer;
  final SICognitiveEntropyController entropyController;
  final SICognitiveResonanceEngine resonanceEngine;
  final SICognitiveTemperatureController temperatureController;
  final SICognitivePhaseShiftEngine phaseShiftEngine;
  final SIContextualGravity contextualGravity;
  final SISyntheticAttentionSystem attentionSystem;
  final SISyntheticInstinctSystem syntheticInstinct;
  final SISyntheticIntuition syntheticIntuition;
  final SISyntheticLanguageGenerator languageGenerator;
  final SISyntheticMetaEmotionEngine metaEmotionEngine;
  final SISyntheticCuriosity curiosityEngine;
  final SICognitiveLawEngine lawEngine;
  final SICognitiveDissonanceResolver dissonanceResolver;
  final SISelfConsistencyEngine consistencyEngine;
  final SICognitiveSelfRepairSystem selfRepairSystem;
  final SICognitiveStyleEngine styleEngine;
  final SIPresenceEngine presenceEngine;
  final SIPersonalityEngine personalityEngine;
  final SIEmotionEngine emotionEngine;
  final UserNarrativeEngine narrativeEngine;
  final SICognitiveHarmonicsSystem harmonicsSystem;

  Future<SIFinalOutputBundle> process({
    required SIInputPacket input,
    SIEngineRuntimeState runtime = const SIEngineRuntimeState(),
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
  }) async {
    final List<String> events = <String>[];
    void mark(String value) =>
        events.add('${DateTime.now().toIso8601String()} | $value');

    try {
      mark('start');
      SIMemoryStore memory = memoryFabric.rebalance(runtime.memory).store;

      SIContext context = inputModule.process(input);
      SIIntent intent = intentModule.extract(context);
      MicroPatternReport patterns = patternEngine.detect(
        context: context,
        memory: memory,
      );
      memory = patternEngine.writeToMemory(memory: memory, report: patterns);

      AdaptiveLearningUpdate learning = adaptiveLearning.update(
        context: context,
        memory: memory,
        patterns: patterns,
        previous: runtime.learning,
      );
      memory = learning.memory;

      final UserStateRefinement refined = userStateEngine.refine(
        context: context,
        memory: memory,
        patterns: patterns,
        learningWeights: learning.weights,
      );
      context = refined.context;

      final InstinctGuidance instinct = instinctModule.evaluate(
        context: context,
        intent: intent,
      );
      final String taskQuery = _taskQuery(input, task);
      final Prediction prediction = predictionEngine.predict(
        history: history,
        task: taskQuery,
      );

      final CognitiveLoadPlan load = loadBalancer.balance(
        context: context,
        intent: intent,
        instinct: instinct,
      );
      entropyController.profile(
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
      );
      final SICognitionState cognition = reasoningModule.process(
        context: context,
        intent: intent,
        instinct: instinct,
        history: history,
        task: taskQuery,
      );
      final PhaseShiftPlan phase = phaseShiftEngine.shift(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        previousPhase: runtime.phase,
      );
      final CognitiveTemperature temp = temperatureController.regulate(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
      );
      final ResonanceProfile resonance = resonanceEngine.resonate(
        context: context,
        intent: intent,
        instinct: instinct,
      );

      final ContextualGravityField gravity = contextualGravity.calculate(
        context: context,
        intent: intent,
        instinct: instinct,
        patterns: patterns,
        learning: learning.weights,
        resonance: resonance,
        memory: memory,
      );

      final AttentionProfile attention = attentionSystem.focus(
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        patterns: patterns,
        learning: learning.weights,
        gravity: gravity,
        resonance: resonance,
      );
      memory = attention.memory;

      final SyntheticInstinctAdvice instinctAdvice = syntheticInstinct.advise(
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        attention: attention,
      );
      memory = instinctAdvice.memory;

      final SyntheticIntuitionResult intuition = syntheticIntuition.evaluate(
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        prediction: prediction,
        patterns: patterns,
        learning: learning.weights,
        attention: attention,
      );
      memory = intuition.memory;

      final TemporalAwarenessReport temporal = temporalEngine.analyze(
        memory: memory,
        context: context,
      );
      memory = temporal.memory;

      final ContinuityProfile continuity = continuityEngine.update(
        context: context,
        memory: memory,
        patterns: patterns,
        learning: learning.weights,
      );
      memory = continuity.memory;

      final UserNarrativeResult narrative = narrativeEngine.build(
        context: context,
        memory: memory,
        intent: intent,
        confidence: intent.confidence,
        goals: goals,
        patterns: patterns,
        learning: learning.weights,
        continuity: continuity,
        previous: runtime.narrative,
      );
      memory = narrative.memory;

      final SIDecision decision = decisionModule.make(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        task: task,
      );

      SIResponse response = responseModule.generate(
        decision: decision,
        instinct: instinct,
        context: context,
        cognition: cognition,
        previousMood: previousMood,
      );

      final CognitiveLawReport laws = lawEngine.apply(
        context: context,
        intent: intent,
        instinct: instinct,
        decision: decision,
        response: response,
      );
      final DissonanceResolution dissonance = dissonanceResolver.resolve(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        decision: decision,
        response: response,
      );
      final ConsistencyResult consistency = consistencyEngine.check(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        decision: decision,
        response: response,
      );
      final CognitiveRepairPlan repair = selfRepairSystem.inspectAndRepair(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        decision: decision,
        response: response,
      );

      final PresenceProfile presence = presenceEngine.calibrate(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        temperature: temp,
      );
      final personality = personalityEngine.resolve(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        decision: decision,
        response: response,
        presence: presence,
      );
      final EmotionModulation emotion = emotionEngine.infer(
        context: context,
        text: response.message,
        previousMood: previousMood,
        patterns: patterns,
        learning: learning.weights,
      );
      final MetaEmotionProfile metaEmotion = metaEmotionEngine.evaluate(
        context: context,
        instinct: instinct,
        memory: memory,
        text: response.message,
        previousMood: previousMood,
        temperature: temp,
        attention: attention,
      );
      memory = metaEmotion.memory;

      String message = laws.enforcedMessage;
      if (dissonance.shouldUseSafeFallback ||
          dissonance.level != DissonanceLevel.none) {
        message = dissonance.adjustedMessage;
      }
      if (!consistency.consistent) message = consistency.preferredMessage;
      if (!repair.healthy) message = repair.repairedMessage;
      if (emotion.recommendedModifier.isNotEmpty &&
          !message.contains(emotion.recommendedModifier)) {
        message = '$message\n\n${emotion.recommendedModifier}';
      }
      if (metaEmotion.toneDirective == 'calm_minimal' &&
          !message.contains('One small step')) {
        message = '$message\n\nOne small step.';
      }

      final CognitiveStylePlan style = styleEngine.plan(
        context: context,
        intent: intent,
        instinct: instinct,
        decision: decision,
      );
      message = styleEngine.apply(message: message, plan: style).text;
      message = narrativeEngine.influenceResponse(
        message: message,
        narrative: narrative.narrative,
        instinct: instinct,
      );

      final SyntheticCuriosityResult curiosity = curiosityEngine.suggest(
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        patterns: patterns,
        learning: learning.weights,
        attention: attention,
      );
      memory = curiosity.memory;
      if (curiosity.prompt != null && curiosity.prompt!.safeToShow) {
        message = '$message\n\n${curiosity.prompt!.text}';
      }

      final SyntheticLanguageResult language = languageGenerator.refine(
        message: message,
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        personality: personality,
        presence: presence,
        loadPlan: load,
        stylePlan: style,
        intuition: intuition,
      );
      memory = language.memory;
      message = language.message;

      final HarmonicsResult harmonics = harmonicsSystem.harmonize(
        message: message,
        context: context,
        intent: intent,
        instinct: instinct,
        memory: memory,
        temperature: temp,
        loadPlan: load,
      );
      memory = harmonics.memory;
      message = harmonics.message;

      final MemoryTopologyUpdate topology = memoryTopology.build(
        current: runtime.topology,
        memory: memory,
        context: context,
        decision: decision,
        response: response,
      );
      memory = topology.memory;

      final MemoryEchoResult echo = memoryEcho.detect(
        memory: memory,
        context: context,
        topology: topology.topology,
      );
      memory = echo.memory;
      message = memoryEcho.applyEchoHint(message, echo.primaryEcho);

      final MemoryWeatherProfile weather = memoryWeather.evaluate(
        memory: memory,
        context: context,
        attention: attention,
        intuition: intuition,
      );
      memory = weather.memory;

      final EcosystemUpdate ecosystem = ecosystemLayer.observe(
        current: runtime.ecosystem,
        memory: memory,
        context: context,
        intent: intent,
        decision: decision,
        response: response,
        patterns: patterns,
      );
      memory = ecosystem.memory;

      final EcosystemEvolutionResult evolved = ecosystemEvolution.evolve(
        state: ecosystem.state,
        memory: memory,
      );
      memory = evolved.memory;

      final EvolutionTimelineUpdate timeline = evolutionTimeline.track(
        current: runtime.timeline,
        memory: memory,
        context: context,
        patterns: patterns,
        ecosystem: evolved.state,
        decision: decision,
      );
      memory = timeline.memory;

      response = SIResponse(
        message: siClean(message, fallback: response.message),
        emotion: emotion.signal.mood,
        persona: personality.persona,
        traits: personality.traits,
        confidence: siClamp01(
          (decision.confidence + intuition.score + weather.intuitionBias) / 3,
        ),
        task: response.task,
      );

      final SIMemoryUpdate memoryUpdate = memoryModule.update(
        current: memory,
        context: context,
        decision: decision,
        response: response,
      );
      memory = memoryUpdate.store;

      final SIDebugTrace trace = SIDebugTrace(
        events: List<String>.unmodifiable(<String>[...events, 'complete']),
        warnings: List<String>.unmodifiable(<String>[
          if (!laws.allowed) 'law_block',
          if (dissonance.level != DissonanceLevel.none)
            'dissonance:${dissonance.level.name}',
          if (!consistency.consistent) 'consistency_repair',
          if (!repair.healthy) 'self_repair:${repair.severity.name}',
        ]),
        metadata: <String, dynamic>{
          'intent': intent.primary.label,
          'phase': phase.phase.name,
          'attention': attention.primaryFocus,
          'trajectory': narrative.narrative.trajectory,
          'temporal_trend': temporal.trend.name,
          'memory_weather': weather.condition.name,
        },
      );

      final SIOutputBundle core = SIOutputBundle(
        context: context,
        intent: intent,
        instinct: instinct,
        cognition: cognition,
        decision: decision,
        response: response,
        memory: memoryUpdate,
        debugTrace: trace,
      );

      return SIFinalOutputBundle(
        core: core,
        runtime: runtime.copyWith(
          memory: memory,
          ecosystem: evolved.state,
          timeline: timeline.timeline,
          topology: topology.topology,
          learning: learning.weights,
          narrative: narrative.narrative,
          phase: phase.phase,
        ),
        patterns: patterns,
        learning: learning,
        temporal: temporal,
        continuity: continuity,
        narrative: narrative,
        attention: attention,
        intuition: intuition,
        curiosity: curiosity,
        debugTrace: trace,
      );
    } catch (error, stackTrace) {
      return _fallback(
        input: input,
        runtime: runtime,
        error: error,
        stackTrace: stackTrace,
        events: events,
      );
    }
  }

  String _taskQuery(SIInputPacket input, Task? task) {
    final String title = siClean(task?.title);
    if (title.isNotEmpty) return title;
    final Object? raw = input.context['task'] ?? input.metadata['task'];
    return siClean(raw?.toString(), fallback: input.text);
  }

  SIFinalOutputBundle _fallback({
    required SIInputPacket input,
    required SIEngineRuntimeState runtime,
    required Object error,
    required StackTrace stackTrace,
    required List<String> events,
  }) {
    final SIContext context = SIContext(
      input: input,
      userState: const SIUserState(
        emotion: 'neutral',
        cognitiveLoad: 0.5,
        stress: 0.5,
        motivation: 0.5,
        engagement: 0.5,
        fatigue: 0.5,
        frustration: 0,
        excitement: 0,
        stability: 'volatile',
      ),
    );

    final SIIntent intent = const SIIntent(
      primary: IntentCandidate(
        label: 'general_query',
        score: 0.5,
        why: 'fallback',
      ),
      predictedNext: 'get_task',
      chain: <String>['general_query'],
    );

    final InstinctGuidance instinct = const InstinctGuidance(
      protectUser: true,
      reduceConfusion: true,
      increaseClarity: true,
      maintainEmotionalSafety: true,
      avoidOverwhelm: true,
      encourageProgress: false,
      maintainContinuity: false,
      primaryInstinct: 'safety_first',
    );

    final SICognitionState cognition = const SICognitionState(
      trace: ReasoningTrace(
        plan: 'Fallback',
        evaluate: 'Engine failed',
        refine: 'Use safe output',
        notes: <AgentNote>[],
      ),
      meta: MetaReasoning(
        misunderstandingRisk: 1,
        askClarification: true,
        slowDown: true,
        switchPersona: false,
        adjustTone: true,
        rationale: 'Fallback.',
      ),
      prediction: SIPrediction(
        outcome: 'Unknown outcome',
        probability: 0.5,
        explanation: 'Unavailable.',
      ),
      summary: 'Fallback safe response.',
    );

    final SIDecision decision = const SIDecision(
      action: 'respond_conversationally',
      score: 0.5,
      reasoning: 'Safe fallback.',
      ethics: EthicsAssessment(
        safe: true,
        flags: <String>['engine_error'],
        adjustments: <String>['safe_fallback'],
      ),
      policyApplied: true,
    );

    final SIResponse response = const SIResponse(
      message:
          'I hit a system issue. Tell me the task or goal, and I’ll help with one small next step.',
      emotion: 'neutral',
      persona: SIPersona.assistant,
      traits: PersonalityTraits(
        warmth: 0.75,
        directness: 0.85,
        humor: 0,
        curiosity: 0.4,
        empathy: 0.85,
      ),
      confidence: 0.5,
    );

    final SIMemoryUpdate memoryUpdate = SIMemoryUpdate(
      store: runtime.memory.pushSnapshot(
        SISnapshot(
          timestamp: DateTime.now(),
          energy: 0.5,
          fatigue: 0.5,
          completed: 0,
          skipped: 0,
          reasoning: 'engine_fallback',
        ),
      ),
      addedSnapshot: SISnapshot(
        timestamp: DateTime.now(),
        energy: 0.5,
        fatigue: 0.5,
        completed: 0,
        skipped: 0,
        reasoning: 'engine_fallback',
      ),
    );

    final SIDebugTrace trace = SIDebugTrace(
      events: List<String>.unmodifiable(<String>[...events, 'fallback']),
      warnings: <String>['engine_error:$error'],
      metadata: <String, dynamic>{'stack_trace': stackTrace.toString()},
    );

    final SIOutputBundle core = SIOutputBundle(
      context: context,
      intent: intent,
      instinct: instinct,
      cognition: cognition,
      decision: decision,
      response: response,
      memory: memoryUpdate,
      debugTrace: trace,
    );

    final emptyPatterns = const MicroPatternReport(
      patterns: <MicroPattern>[],
      predictionSignals: <String, double>{},
      summary: 'fallback',
    );
    final emptyLearning = AdaptiveLearningUpdate(
      weights: runtime.learning,
      memory: memoryUpdate.store,
      recommendations: const <String>['fallback'],
      predictionSignals: const <String, double>{},
    );
    final emptyTemporal = TemporalAwarenessReport(
      recencyBias: 0.5,
      momentum: 0.5,
      trend: TemporalTrend.insufficientData,
      cycles: const <TemporalCycle>[],
      timingAdvice: 'Fallback.',
      memory: memoryUpdate.store,
    );
    final emptyContinuity = ContinuityProfile(
      identityLabel: 'steady_operator',
      goals: const <String>[],
      behaviorPatterns: const <String>[],
      continuityScore: 0.5,
      driftRisk: 0.5,
      memory: memoryUpdate.store,
    );
    final emptyNarrative = narrativeEngine.build(
      context: context,
      memory: memoryUpdate.store,
      intent: intent,
    );

    return SIFinalOutputBundle(
      core: core,
      runtime: runtime.copyWith(memory: memoryUpdate.store),
      patterns: emptyPatterns,
      learning: emptyLearning,
      temporal: emptyTemporal,
      continuity: emptyContinuity,
      narrative: emptyNarrative,
      attention: AttentionProfile(
        signals: const <AttentionSignal>[],
        primaryFocus: 'fallback',
        focusScore: 0.5,
        memory: memoryUpdate.store,
      ),
      intuition: SyntheticIntuitionResult(
        score: 0.5,
        confidence: 0.5,
        signals: const <IntuitionSignal>[],
        recommendation: 'fallback',
        memory: memoryUpdate.store,
      ),
      curiosity: SyntheticCuriosityResult(
        prompt: null,
        memory: memoryUpdate.store,
      ),
      debugTrace: trace,
    );
  }
}
