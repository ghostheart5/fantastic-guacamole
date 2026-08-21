import 'dart:collection';

import 'package:fantastic_guacamole/state/state/emotional_state.dart';

enum PlannerResponseOrigin { deterministic, externalModel }

enum PlannerOptionKind { minimum, bestFit, stretch }

enum PlannerActionControl {
  tryThis,
  editUnderstanding,
  makeItSmaller,
  differentApproach,
  whyThis,
  openCreatorDraft,
  notNow,
}

final class PlannerOption {
  const PlannerOption({
    required this.kind,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.tradeoff,
  });

  final PlannerOptionKind kind;
  final String title;
  final String description;
  final int estimatedMinutes;
  final String tradeoff;

  PlannerOption copyWith({
    PlannerOptionKind? kind,
    String? title,
    String? description,
    int? estimatedMinutes,
    String? tradeoff,
  }) => PlannerOption(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    description: description ?? this.description,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    tradeoff: tradeoff ?? this.tradeoff,
  );
}

final class PlannerAdaptationReceipt {
  PlannerAdaptationReceipt({
    required this.userSetEnergy,
    required this.userSelectedEmotion,
    required List<String> adjustments,
  }) : adjustments = List<String>.unmodifiable(adjustments) {
    if (userSetEnergy < 0 || userSetEnergy > 1) {
      throw ArgumentError.value(
        userSetEnergy,
        'userSetEnergy',
        'Energy must be between zero and one.',
      );
    }
    if (adjustments.isEmpty) {
      throw ArgumentError.value(
        adjustments,
        'adjustments',
        'At least one explicit adaptation is required.',
      );
    }
  }

  final double userSetEnergy;
  final EmotionalState userSelectedEmotion;
  final List<String> adjustments;

  int get energyPercent => (userSetEnergy * 100).round();
}

final class PlannerV2Response {
  PlannerV2Response({
    required this.whatIHeard,
    required this.mattersMost,
    required List<String> verifiedEvidence,
    required List<PlannerOption> options,
    required this.recommendedKind,
    required this.recommendationReason,
    required this.nextStep,
    this.usefulQuestion,
    required this.adaptationReceipt,
    required this.origin,
    List<PlannerActionControl> controls = PlannerActionControl.values,
  }) : verifiedEvidence = List<String>.unmodifiable(verifiedEvidence),
       options = List<PlannerOption>.unmodifiable(options),
       controls = List<PlannerActionControl>.unmodifiable(controls) {
    _validate();
  }

  final String whatIHeard;
  final String mattersMost;
  final List<String> verifiedEvidence;
  final List<PlannerOption> options;
  final PlannerOptionKind recommendedKind;
  final String recommendationReason;
  final String nextStep;
  final String? usefulQuestion;
  final PlannerAdaptationReceipt adaptationReceipt;
  final PlannerResponseOrigin origin;
  final List<PlannerActionControl> controls;

  PlannerOption get recommendedOption => options.singleWhere(
    (PlannerOption option) => option.kind == recommendedKind,
  );

  UnmodifiableMapView<PlannerOptionKind, PlannerOption> get optionByKind =>
      UnmodifiableMapView<PlannerOptionKind, PlannerOption>(
        <PlannerOptionKind, PlannerOption>{
          for (final PlannerOption option in options) option.kind: option,
        },
      );

  PlannerV2Response copyWith({
    String? whatIHeard,
    String? mattersMost,
    List<String>? verifiedEvidence,
    List<PlannerOption>? options,
    PlannerOptionKind? recommendedKind,
    String? recommendationReason,
    String? nextStep,
    String? usefulQuestion,
    PlannerAdaptationReceipt? adaptationReceipt,
    PlannerResponseOrigin? origin,
    List<PlannerActionControl>? controls,
  }) => PlannerV2Response(
    whatIHeard: whatIHeard ?? this.whatIHeard,
    mattersMost: mattersMost ?? this.mattersMost,
    verifiedEvidence: verifiedEvidence ?? this.verifiedEvidence,
    options: options ?? this.options,
    recommendedKind: recommendedKind ?? this.recommendedKind,
    recommendationReason: recommendationReason ?? this.recommendationReason,
    nextStep: nextStep ?? this.nextStep,
    usefulQuestion: usefulQuestion ?? this.usefulQuestion,
    adaptationReceipt: adaptationReceipt ?? this.adaptationReceipt,
    origin: origin ?? this.origin,
    controls: controls ?? this.controls,
  );

  PlannerV2Response recommend(PlannerOptionKind kind, {required String why}) {
    final PlannerOption option = optionByKind[kind]!;
    return copyWith(
      recommendedKind: kind,
      recommendationReason: why,
      nextStep: option.description,
    );
  }

  String toAccessibleText() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('What I heard: $whatIHeard')
      ..writeln('What matters most: $mattersMost')
      ..writeln('Plan spectrum:');
    for (final PlannerOption option in options) {
      buffer.writeln(
        '${_kindLabel(option.kind)}: ${option.title}. ${option.description}',
      );
    }
    buffer
      ..writeln('Recommended: ${recommendedOption.title}')
      ..writeln('Why: $recommendationReason')
      ..writeln('Next step: $nextStep');
    final String question = usefulQuestion?.trim() ?? '';
    if (question.isNotEmpty) {
      buffer.writeln('Useful question: $question');
    }
    return buffer.toString().trim();
  }

  void _validate() {
    final Set<PlannerOptionKind> kinds = options
        .map((PlannerOption option) => option.kind)
        .toSet();
    if (options.length != PlannerOptionKind.values.length ||
        kinds.length != PlannerOptionKind.values.length ||
        !kinds.containsAll(PlannerOptionKind.values)) {
      throw ArgumentError.value(
        options,
        'options',
        'Plan Spectrum requires exactly one Minimum, Best-fit, and Stretch option.',
      );
    }
    if (!kinds.contains(recommendedKind)) {
      throw ArgumentError.value(
        recommendedKind,
        'recommendedKind',
        'The recommended option must exist in the Plan Spectrum.',
      );
    }
    if (verifiedEvidence.isEmpty) {
      throw ArgumentError.value(
        verifiedEvidence,
        'verifiedEvidence',
        'Planner V2 responses require explicit evidence.',
      );
    }
    if (controls.toSet().length != PlannerActionControl.values.length ||
        !controls.toSet().containsAll(PlannerActionControl.values)) {
      throw ArgumentError.value(
        controls,
        'controls',
        'Planner V2 responses require all explicit action controls.',
      );
    }
  }

  static String _kindLabel(PlannerOptionKind kind) => switch (kind) {
    PlannerOptionKind.minimum => 'Minimum',
    PlannerOptionKind.bestFit => 'Best-fit',
    PlannerOptionKind.stretch => 'Stretch',
  };
}
