// lib/engine/si/ai_response.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_output_bundle.dart';

const AIPersonalityProfile _defaultAIPersonalityProfile = AIPersonalityProfile(
  persona: SIPersona.assistant,
  traits: PersonalityTraits(
    warmth: 0.65,
    directness: 0.6,
    humor: 0.2,
    curiosity: 0.55,
    empathy: 0.7,
  ),
  style: AIStyleDirective(
    tone: 'clear_direct',
    maxWords: 60,
    useSteps: false,
    allowHumor: true,
    pressureLevel: 0.2,
  ),
  identity: 'clarity assistant',
);

class AIResponse {
  const AIResponse({
    required this.message,
    required this.confidence,
    required this.emotion,
    this.personality = _defaultAIPersonalityProfile,
    this.action = 'respond_conversationally',
    this.safe = true,
    this.task,
    this.reasoning = '',
    this.taskTitle,
    this.metadata = const <String, dynamic>{},
  });

  final String message;
  final double confidence;
  final String emotion;
  final AIPersonalityProfile personality;
  final String action;
  final bool safe;
  final Task? task;
  final String reasoning;
  final String? taskTitle;
  final Map<String, dynamic> metadata;

  factory AIResponse.fromSIResponse({
    required SIResponse response,
    SIDecision? decision,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return AIResponse(
      message: siClean(response.message, fallback: 'I am ready when you are.'),
      confidence: siClamp01(response.confidence),
      emotion: siNormalizeMood(response.emotion),
      personality: AIPersonalityProfile.fromResponse(response),
      action: decision?.action ?? 'respond_conversationally',
      safe: decision?.safe ?? true,
      task: response.task,
      reasoning: decision?.reasoning ?? response.message,
      taskTitle: response.task?.title,
      metadata: Map<String, dynamic>.unmodifiable(metadata),
    );
  }

  factory AIResponse.fromBundle(SIOutputBundle bundle) {
    return AIResponse.fromSIResponse(
      response: bundle.response,
      decision: bundle.decision,
      metadata: <String, dynamic>{
        'intent': bundle.intent.primary.label,
        'predicted_next': bundle.intent.predictedNext,
        'instinct': bundle.instinct.primaryInstinct,
        'memory_snapshots': bundle.memory.store.snapshots.length,
        'debug_events': bundle.debugTrace.events.length,
      },
    );
  }

  AIResponse copyWith({
    String? message,
    double? confidence,
    String? emotion,
    AIPersonalityProfile? personality,
    String? action,
    bool? safe,
    Task? task,
    String? reasoning,
    String? taskTitle,
    Map<String, dynamic>? metadata,
  }) {
    return AIResponse(
      message: message ?? this.message,
      confidence: siClamp01(confidence ?? this.confidence),
      emotion: emotion ?? this.emotion,
      personality: personality ?? this.personality,
      action: action ?? this.action,
      safe: safe ?? this.safe,
      task: task ?? this.task,
      reasoning: reasoning ?? this.reasoning,
      taskTitle: taskTitle ?? this.taskTitle,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message': message,
    'confidence': siClamp01(confidence),
    'emotion': emotion,
    'personality': personality.toJson(),
    'action': action,
    'safe': safe,
    'task': task?.toJson(),
    'reasoning': reasoning,
    'task_title': taskTitle,
    'metadata': metadata,
  };
}
