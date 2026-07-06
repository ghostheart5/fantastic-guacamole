// lib/engine/si/synthetic_intelligence_engine.dart

import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_engine_service.dart';

typedef SyntheticIntelligenceOutput = SIFinalOutputBundle;

class SyntheticIntelligenceEngine {
  SyntheticIntelligenceEngine({SIEngineService? service})
    : _service = service ?? SIEngineService();

  final SIEngineService _service;

  SIEngineRuntimeState get runtime => _service.runtime;
  SIMemoryStore get memory => _service.memory;

  Future<SIFinalOutputBundle> build({
    required String input,
    required DateTime now,
    Object? personality,
    AIResponse? response,
    String appState = 'coach',
    String platform = 'unknown',
    List<String> history = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> context = const <String, dynamic>{},
    SINonTextInputs nonText = const SINonTextInputs(),
    SILatentInputs? latent,
    Object? policy,
    String? previousMood,
    List<NeuralEntry> neuralHistory = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    SIEngineRuntimeState? runtime,
  }) async {
    final SILatentInputs resolvedLatent =
        latent ?? _inferLatent(input: input, nonText: nonText);

    final Map<String, dynamic> mergedMetadata = _mergeMetadata(
      metadata: metadata,
      now: now,
      appState: appState,
      platform: platform,
      personality: personality,
      response: response,
      policy: policy,
    );

    final Map<String, dynamic> mergedContext = _mergeContext(
      context: context,
      appState: appState,
      platform: platform,
      response: response,
      goals: goals,
    );

    final SIInputPacket packet = SIInputPacket(
      text: input,
      history: List<String>.unmodifiable(history),
      metadata: mergedMetadata,
      context: mergedContext,
      nonText: nonText,
      latent: resolvedLatent,
    );

    return _service.handleUserInput(
      packet,
      history: neuralHistory,
      task: task,
      goals: _mergedGoals(
        explicitGoals: goals,
        metadata: mergedMetadata,
        context: mergedContext,
      ),
      previousMood: previousMood,
      runtime: runtime,
    );
  }

  Future<SIFinalOutputBundle> buildFromPacket({
    required SIInputPacket packet,
    List<NeuralEntry> neuralHistory = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
    SIEngineRuntimeState? runtime,
  }) {
    return _service.handleUserInput(
      packet,
      history: neuralHistory,
      task: task,
      goals: goals,
      previousMood: previousMood,
      runtime: runtime,
    );
  }

  Future<AIResponse> buildAIResponse({
    required String input,
    required DateTime now,
    Object? personality,
    AIResponse? response,
    String appState = 'coach',
    String platform = 'unknown',
    List<String> history = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> context = const <String, dynamic>{},
    SINonTextInputs nonText = const SINonTextInputs(),
    SILatentInputs? latent,
    Object? policy,
    String? previousMood,
    List<NeuralEntry> neuralHistory = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    SIEngineRuntimeState? runtime,
  }) async {
    final SIFinalOutputBundle output = await build(
      input: input,
      now: now,
      personality: personality,
      response: response,
      appState: appState,
      platform: platform,
      history: history,
      metadata: metadata,
      context: context,
      nonText: nonText,
      latent: latent,
      policy: policy,
      previousMood: previousMood,
      neuralHistory: neuralHistory,
      task: task,
      goals: goals,
      runtime: runtime,
    );

    return AIResponse.fromBundle(output.core);
  }

  void replaceRuntime(SIEngineRuntimeState runtime) {
    _service.replaceRuntime(runtime);
  }

  void replaceMemory(SIMemoryStore memory) {
    _service.replaceMemory(memory);
  }

  void clear() {
    _service.clear();
  }

  SILatentInputs _inferLatent({
    required String input,
    required SINonTextInputs nonText,
  }) {
    final String lowered = input.toLowerCase().trim();
    final List<String> behavior = nonText.behaviorPatterns
        .map((String value) => value.toLowerCase())
        .toList(growable: false);

    final bool pausePattern = behavior.any(
      (String pattern) =>
          pattern.contains('pause') ||
          pattern.contains('hesitat') ||
          pattern.contains('delay'),
    );

    double frustration = 0.1;
    double excitement = 0.1;
    double confusion = 0.1;
    double confidence = 0.5;
    double hesitation = pausePattern ? 0.55 : 0.2;

    if (_containsAny(lowered, const <String>[
      'stuck',
      'annoyed',
      'frustrated',
      'frustrating',
      'blocked',
      'overwhelmed',
    ])) {
      frustration = 0.75;
      confidence = 0.35;
      hesitation = hesitation < 0.5 ? 0.5 : hesitation;
    }

    if (_containsAny(lowered, const <String>[
      'great',
      'awesome',
      'excited',
      'ready',
      'motivated',
      'momentum',
    ])) {
      excitement = 0.8;
      confidence = confidence < 0.75 ? 0.75 : confidence;
    }

    if (_containsAny(lowered, const <String>[
      'confused',
      'not sure',
      'unclear',
      'lost',
      'don’t know',
      "don't know",
    ])) {
      confusion = 0.72;
      confidence = 0.3;
      hesitation = 0.6;
    }

    if ((nonText.voiceToText ?? '').trim().isNotEmpty && lowered.isEmpty) {
      confidence = 0.6;
    }

    return SILatentInputs(
      frustration: siClamp01(frustration, fallback: 0.1),
      excitement: siClamp01(excitement, fallback: 0.1),
      confusion: siClamp01(confusion, fallback: 0.1),
      confidence: siClamp01(confidence, fallback: 0.5),
      hesitation: siClamp01(hesitation, fallback: 0.2),
    );
  }

  Map<String, dynamic> _mergeMetadata({
    required Map<String, dynamic> metadata,
    required DateTime now,
    required String appState,
    required String platform,
    required Object? personality,
    required AIResponse? response,
    required Object? policy,
  }) {
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      ...metadata,
      'si_engine': 'synthetic_intelligence_engine',
      'timestamp': now.toIso8601String(),
      'app_state': appState,
      'platform': platform,
      if (personality != null) 'personality': _safeObject(personality),
      if (response != null) 'seed_response': response.toJson(),
      if (policy != null) 'policy': _safeObject(policy),
    });
  }

  Map<String, dynamic> _mergeContext({
    required Map<String, dynamic> context,
    required String appState,
    required String platform,
    required AIResponse? response,
    required List<String> goals,
  }) {
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      ...context,
      'app_state': appState,
      'platform': platform,
      if (response?.message.trim().isNotEmpty == true)
        'seed_response_message': response!.message,
      if (response?.taskTitle?.trim().isNotEmpty == true)
        'seed_response_task_title': response!.taskTitle,
      if (goals.isNotEmpty) 'goals': List<String>.unmodifiable(goals),
    });
  }

  List<String> _mergedGoals({
    required List<String> explicitGoals,
    required Map<String, dynamic> metadata,
    required Map<String, dynamic> context,
  }) {
    final Set<String> output = <String>{};

    for (final String goal in explicitGoals) {
      final String clean = siClean(goal);
      if (clean.isNotEmpty) output.add(clean);
    }

    void addFrom(Object? value) {
      if (value == null) return;

      if (value is Iterable) {
        for (final Object? item in value) {
          final String clean = siClean(item?.toString());
          if (clean.isNotEmpty) output.add(clean);
        }
        return;
      }

      final String clean = siClean(value.toString());
      if (clean.isNotEmpty) output.add(clean);
    }

    addFrom(metadata['goal']);
    addFrom(metadata['goals']);
    addFrom(context['goal']);
    addFrom(context['goals']);

    return List<String>.unmodifiable(output);
  }

  Object _safeObject(Object value) {
    if (value is String ||
        value is num ||
        value is bool ||
        value is List ||
        value is Map) {
      return value;
    }

    try {
      final Object? json = jsonDecode(jsonEncode(value));
      if (json is String ||
          json is num ||
          json is bool ||
          json is List ||
          json is Map) {
        return json as Object;
      }
    } catch (_) {
      // Keep fallback below.
    }

    return value.toString();
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any((String pattern) => text.contains(pattern));
  }
}
