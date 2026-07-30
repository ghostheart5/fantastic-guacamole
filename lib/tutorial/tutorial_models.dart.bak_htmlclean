// lib/tutorial/tutorial_models.dart

import 'dart:convert';

enum TutorialTriggerType { tap, longPress, route, state, input, delay, manual }

enum TutorialBlockMode { blockAll, allowTarget, nonBlocking }

class TutorialDefinition {
  const TutorialDefinition({
    required this.id,
    required this.title,
    required this.steps,
    this.version = 1,
  });

  final String id;
  final String title;
  final int version;
  final List<TutorialStep> steps;

  factory TutorialDefinition.fromJson(Map<String, dynamic> json) {
    return TutorialDefinition(
      id: json['id']?.toString() ?? 'tutorial',
      title: json['title']?.toString() ?? 'Tutorial',
      version: (json['version'] as num?)?.toInt() ?? 1,
      steps: ((json['steps'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map((e) => TutorialStep.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }

  static TutorialDefinition decode(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const TutorialDefinition(
        id: 'tutorial',
        title: 'Tutorial',
        steps: <TutorialStep>[],
      );
    }
    return TutorialDefinition.fromJson(decoded);
  }
}

class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.body,
    required this.trigger,
    this.targetId,
    this.route,
    this.inputKey,
    this.expectedValue,
    this.stateKey,
    this.stateValue,
    this.nextStepId,
    this.delayMs = 0,
    this.autoAdvance = false,
    this.blockMode = TutorialBlockMode.allowTarget,
    this.branches = const <TutorialBranch>[],
  });

  final String id;
  final String title;
  final String body;
  final TutorialTriggerType trigger;
  final String? targetId;
  final String? route;
  final String? inputKey;
  final String? expectedValue;
  final String? stateKey;
  final Object? stateValue;
  final String? nextStepId;
  final int delayMs;
  final bool autoAdvance;
  final TutorialBlockMode blockMode;
  final List<TutorialBranch> branches;

  factory TutorialStep.fromJson(Map<String, dynamic> json) {
    return TutorialStep(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      trigger: _trigger(json['trigger']?.toString()),
      targetId: json['targetId']?.toString(),
      route: json['route']?.toString(),
      inputKey: json['inputKey']?.toString(),
      expectedValue: json['expectedValue']?.toString(),
      stateKey: json['stateKey']?.toString(),
      stateValue: json['stateValue'],
      nextStepId: json['nextStepId']?.toString(),
      delayMs: (json['delayMs'] as num?)?.toInt() ?? 0,
      autoAdvance: json['autoAdvance'] == true,
      blockMode: _block(json['blockMode']?.toString()),
      branches: ((json['branches'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map((e) => TutorialBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }

  static TutorialTriggerType _trigger(String? value) {
    return TutorialTriggerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TutorialTriggerType.manual,
    );
  }

  static TutorialBlockMode _block(String? value) {
    return TutorialBlockMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TutorialBlockMode.allowTarget,
    );
  }
}

class TutorialBranch {
  const TutorialBranch({
    required this.whenKey,
    required this.equalsValue,
    required this.gotoStepId,
  });

  final String whenKey;
  final Object? equalsValue;
  final String gotoStepId;

  factory TutorialBranch.fromJson(Map<String, dynamic> json) {
    return TutorialBranch(
      whenKey: json['whenKey']?.toString() ?? '',
      equalsValue: json['equals'],
      gotoStepId: json['goto']?.toString() ?? '',
    );
  }
}
