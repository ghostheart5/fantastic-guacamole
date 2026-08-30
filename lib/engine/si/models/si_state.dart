// lib/engine/si/models/si_state.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';

part 'si_memory_store_models.dart';

double siClamp01(num? value, {double fallback = 0.5}) {
  if (value == null || !value.isFinite) return fallback;
  return value.clamp(0.0, 1.0).toDouble();
}

String siClean(String? value, {String fallback = ''}) {
  final String clean = value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return clean.isEmpty ? fallback : clean;
}

String siNormalizeMood(String? value) {
  final String mood = siClean(value, fallback: 'neutral').toLowerCase();
  return mood.isEmpty ? 'neutral' : mood;
}

class SIState {
  const SIState({
    this.energy = 0.5,
    this.fatigue = 0.5,
    this.completedToday = 0,
    this.energyOrigin = PredictiveEvidenceOrigin.unavailable,
    this.fatigueOrigin = PredictiveEvidenceOrigin.unavailable,
  });

  final double energy;
  final double fatigue;
  final int completedToday;
  final PredictiveEvidenceOrigin energyOrigin;
  final PredictiveEvidenceOrigin fatigueOrigin;

  bool get hasObservedEnergy =>
      energyOrigin == PredictiveEvidenceOrigin.observed;
  bool get hasObservedFatigue =>
      fatigueOrigin == PredictiveEvidenceOrigin.observed;

  SIState copyWith({
    double? energy,
    double? fatigue,
    int? completedToday,
    PredictiveEvidenceOrigin? energyOrigin,
    PredictiveEvidenceOrigin? fatigueOrigin,
  }) {
    return SIState(
      energy: siClamp01(energy ?? this.energy, fallback: this.energy),
      fatigue: siClamp01(fatigue ?? this.fatigue, fallback: this.fatigue),
      completedToday: completedToday ?? this.completedToday,
      energyOrigin: energyOrigin ?? this.energyOrigin,
      fatigueOrigin: fatigueOrigin ?? this.fatigueOrigin,
    );
  }
}

// ─── Input / Context ─────────────────────────────────────────────────────────

class SINonTextInputs {
  const SINonTextInputs({
    this.voiceToText,
    this.imageLabels = const <String>[],
    this.uiState = const <String, dynamic>{},
    this.sensorData = const <String, dynamic>{},
    this.timeTriggers = const <String>[],
    this.behaviorPatterns = const <String>[],
  });

  final String? voiceToText;
  final List<String> imageLabels;
  final Map<String, dynamic> uiState;
  final Map<String, dynamic> sensorData;
  final List<String> timeTriggers;
  final List<String> behaviorPatterns;
}

class SILatentInputs {
  const SILatentInputs({
    this.frustration = 0,
    this.excitement = 0,
    this.confusion = 0,
    this.confidence = 0.5,
    this.hesitation = 0,
  });

  final double frustration;
  final double excitement;
  final double confusion;
  final double confidence;
  final double hesitation;
}

class SIInputPacket {
  const SIInputPacket({
    required this.text,
    this.history = const <String>[],
    this.metadata = const <String, dynamic>{},
    this.context = const <String, dynamic>{},
    this.nonText = const SINonTextInputs(),
    this.latent = const SILatentInputs(),
  });

  final String text;
  final List<String> history;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> context;
  final SINonTextInputs nonText;
  final SILatentInputs latent;
}

class SIUserState {
  const SIUserState({
    required this.emotion,
    required this.cognitiveLoad,
    required this.stress,
    required this.motivation,
    required this.engagement,
    required this.fatigue,
    required this.frustration,
    required this.excitement,
    required this.stability,
  });

  final String emotion;
  final double cognitiveLoad;
  final double stress;
  final double motivation;
  final double engagement;
  final double fatigue;
  final double frustration;
  final double excitement;
  final String stability;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'emotion': emotion,
    'cognitive_load': siClamp01(cognitiveLoad),
    'stress': siClamp01(stress),
    'motivation': siClamp01(motivation),
    'engagement': siClamp01(engagement),
    'fatigue': siClamp01(fatigue),
    'frustration': siClamp01(frustration),
    'excitement': siClamp01(excitement),
    'stability': stability,
  };
}

class SIContext {
  const SIContext({required this.input, required this.userState});

  final SIInputPacket input;
  final SIUserState userState;
}

// ─── Intent ──────────────────────────────────────────────────────────────────

class IntentCandidate {
  const IntentCandidate({
    required this.label,
    required this.score,
    required this.why,
  });

  final String label;
  final double score;
  final String why;

  double get confidence => siClamp01(score);
}

class SIIntent {
  const SIIntent({
    required this.primary,
    this.secondary,
    this.hidden,
    required this.predictedNext,
    required this.chain,
  });

  final IntentCandidate primary;
  final IntentCandidate? secondary;
  final IntentCandidate? hidden;
  final String predictedNext;
  final List<String> chain;

  bool get isComplex => secondary != null || hidden != null;
  double get confidence => primary.confidence;
}

// ─── Instinct ────────────────────────────────────────────────────────────────

class InstinctGuidance {
  const InstinctGuidance({
    required this.protectUser,
    required this.reduceConfusion,
    required this.increaseClarity,
    required this.maintainEmotionalSafety,
    required this.avoidOverwhelm,
    required this.encourageProgress,
    required this.maintainContinuity,
    required this.primaryInstinct,
  });

  final bool protectUser;
  final bool reduceConfusion;
  final bool increaseClarity;
  final bool maintainEmotionalSafety;
  final bool avoidOverwhelm;
  final bool encourageProgress;
  final bool maintainContinuity;
  final String primaryInstinct;

  bool get safetyFirst => primaryInstinct == 'safety_first';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protect_user': protectUser,
    'reduce_confusion': reduceConfusion,
    'increase_clarity': increaseClarity,
    'maintain_emotional_safety': maintainEmotionalSafety,
    'avoid_overwhelm': avoidOverwhelm,
    'encourage_progress': encourageProgress,
    'maintain_continuity': maintainContinuity,
    'primary_instinct': primaryInstinct,
  };
}

// ─── Cognition / Reasoning ───────────────────────────────────────────────────

class AgentNote {
  const AgentNote({required this.agent, required this.note});

  final String agent;
  final String note;
}

class ReasoningTrace {
  const ReasoningTrace({
    required this.plan,
    required this.evaluate,
    required this.refine,
    required this.notes,
  });

  final String plan;
  final String evaluate;
  final String refine;
  final List<AgentNote> notes;
}

class MetaReasoning {
  const MetaReasoning({
    required this.misunderstandingRisk,
    required this.askClarification,
    required this.slowDown,
    required this.switchPersona,
    required this.adjustTone,
    required this.rationale,
  });

  final double misunderstandingRisk;
  final bool askClarification;
  final bool slowDown;
  final bool switchPersona;
  final bool adjustTone;
  final String rationale;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'misunderstanding_risk': siClamp01(misunderstandingRisk),
    'ask_clarification': askClarification,
    'slow_down': slowDown,
    'switch_persona': switchPersona,
    'adjust_tone': adjustTone,
    'rationale': rationale,
  };
}

class SIPrediction {
  const SIPrediction({
    required this.outcome,
    required this.probability,
    required this.explanation,
  });

  final String outcome;
  final double probability;
  final String explanation;

  double get safeProbability => siClamp01(probability);
}

class SICognitionState {
  const SICognitionState({
    required this.trace,
    required this.meta,
    required this.prediction,
    required this.summary,
  });

  final ReasoningTrace trace;
  final MetaReasoning meta;
  final SIPrediction prediction;
  final String summary;
}

// ─── Decision ────────────────────────────────────────────────────────────────

class EthicsAssessment {
  const EthicsAssessment({
    required this.safe,
    required this.flags,
    required this.adjustments,
  });

  final bool safe;
  final List<String> flags;
  final List<String> adjustments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'safe': safe,
    'flags': flags,
    'adjustments': adjustments,
  };
}

class SIDecisionPolicy {
  const SIDecisionPolicy({
    this.safety = true,
    this.tone = 'balanced',
    this.domainRules = const <String>['productivity'],
    this.emotionalRules = const <String>['be_supportive', 'avoid_harshness'],
    this.appConstraints = const <String>[
      'no_destructive_actions_without_confirmation',
    ],
  });

  final bool safety;
  final String tone;
  final List<String> domainRules;
  final List<String> emotionalRules;
  final List<String> appConstraints;
}

class SIDecision {
  const SIDecision({
    required this.action,
    this.task,
    required this.score,
    required this.reasoning,
    required this.ethics,
    required this.policyApplied,
  });

  final String action;
  final Task? task;
  final double score;
  final String reasoning;
  final EthicsAssessment ethics;
  final bool policyApplied;

  bool get safe => ethics.safe;
  double get confidence => siClamp01(score);
}

// ─── Response ────────────────────────────────────────────────────────────────

enum SIPersona { mentor, assistant, planner, companion, analyst }

class PersonalityTraits {
  const PersonalityTraits({
    required this.warmth,
    required this.directness,
    required this.humor,
    required this.curiosity,
    required this.empathy,
  });

  final double warmth;
  final double directness;
  final double humor;
  final double curiosity;
  final double empathy;
}

class EmotionalSignal {
  const EmotionalSignal({
    required this.mood,
    required this.intensity,
    required this.shift,
  });

  final String mood;
  final double intensity;
  final String shift;

  bool get highIntensity => siClamp01(intensity) >= 0.7;
}

class SIResponse {
  const SIResponse({
    required this.message,
    required this.emotion,
    required this.persona,
    required this.traits,
    required this.confidence,
    this.task,
  });

  final String message;
  final String emotion;
  final SIPersona persona;
  final PersonalityTraits traits;
  final double confidence;
  final Task? task;

  String get taskTitle => task?.title ?? 'No active tasks';
  double get safeConfidence => siClamp01(confidence);
}
