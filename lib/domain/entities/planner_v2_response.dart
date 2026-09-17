// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner V2
import 'dart:collection';

import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';

enum PlannerResponseOrigin { deterministic, externalModel }

enum PlannerResponseDisposition { guidance, clarification }

enum PlannerOptionKind { minimum, bestFit, stretch }

enum PlannerAdjustmentKind { smaller, rejectedApproach }

/// A UI adjustment is conversation context, not a user-authored life fact.
final class PlannerAdjustment {
  const PlannerAdjustment({
    required this.kind,
    required this.description,
    this.previousMinutes,
    this.currentMinutes,
  });

  final PlannerAdjustmentKind kind;
  final String description;
  final int? previousMinutes;
  final int? currentMinutes;
}

/// Only facts supplied by the user, retained independently of display history.
/// Generated recommendations and button descriptions do not belong here.
final class PlannerUserContext {
  PlannerUserContext({
    required this.objective,
    List<String> corrections = const <String>[],
    this.savedContextDeclined = false,
    this.timeLimitMinutes,
    this.timeLimitSeconds,
  }) : corrections = List<String>.unmodifiable(corrections);

  final String objective;
  final List<String> corrections;
  final bool savedContextDeclined;
  final int? timeLimitMinutes;

  /// Exact user-authored limit when the window is shorter than a minute.
  /// [timeLimitMinutes] remains available for ranking compatibility.
  final int? timeLimitSeconds;
}

final class PlannerConversationSnapshot {
  PlannerConversationSnapshot({
    required this.originalObjective,
    required this.currentPlan,
    this.userContext,
    List<PlannerAdjustment> adjustments = const <PlannerAdjustment>[],
  }) : adjustments = List<PlannerAdjustment>.unmodifiable(adjustments);

  final String originalObjective;
  final PlannerV2Response currentPlan;
  final PlannerUserContext? userContext;
  final List<PlannerAdjustment> adjustments;
}

enum PlannerActionControl {
  useThisPlan,
  makeSmaller,
  differentApproach,
  whyThis,
  evidence,
}

final class PlannerOption {
  const PlannerOption({
    required this.kind,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    this.estimatedSeconds,
    required this.tradeoff,
  });

  final PlannerOptionKind kind;
  final String title;
  final String description;
  final int estimatedMinutes;

  /// Exact display/voice duration for sub-minute plans.
  final int? estimatedSeconds;
  final String tradeoff;

  PlannerOption copyWith({
    PlannerOptionKind? kind,
    String? title,
    String? description,
    int? estimatedMinutes,
    int? estimatedSeconds,
    bool clearEstimatedSeconds = false,
    String? tradeoff,
  }) => PlannerOption(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    description: description ?? this.description,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    estimatedSeconds: clearEstimatedSeconds
        ? null
        : estimatedSeconds ?? this.estimatedSeconds,
    tradeoff: tradeoff ?? this.tradeoff,
  );
}

final class PlannerAdaptationReceipt {
  PlannerAdaptationReceipt({
    required this.userSetEnergy,
    required this.userSelectedEmotion,
    required List<String> adjustments,
  }) : adjustments = List<String>.unmodifiable(adjustments) {
    if (userSetEnergy != null && (userSetEnergy! < 0 || userSetEnergy! > 1)) {
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

  final double? userSetEnergy;
  final EmotionalState? userSelectedEmotion;
  final List<String> adjustments;

  int? get energyPercent =>
      userSetEnergy == null ? null : (userSetEnergy! * 100).round();
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
    this.languageCode = 'en',
    this.userContext,
    this.disposition = PlannerResponseDisposition.guidance,
    this.conversationReply,
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
  final String languageCode;
  final PlannerUserContext? userContext;
  final PlannerResponseDisposition disposition;

  /// A direct answer to a follow-up, separate from the retained plan actions.
  final String? conversationReply;
  final List<PlannerActionControl> controls;

  bool get isClarification =>
      disposition == PlannerResponseDisposition.clarification;

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
    bool clearUsefulQuestion = false,
    PlannerAdaptationReceipt? adaptationReceipt,
    PlannerResponseOrigin? origin,
    String? languageCode,
    PlannerUserContext? userContext,
    String? conversationReply,
    bool clearConversationReply = false,
    PlannerResponseDisposition? disposition,
    List<PlannerActionControl>? controls,
  }) => PlannerV2Response(
    whatIHeard: whatIHeard ?? this.whatIHeard,
    mattersMost: mattersMost ?? this.mattersMost,
    verifiedEvidence: verifiedEvidence ?? this.verifiedEvidence,
    options: options ?? this.options,
    recommendedKind: recommendedKind ?? this.recommendedKind,
    recommendationReason: recommendationReason ?? this.recommendationReason,
    nextStep: nextStep ?? this.nextStep,
    usefulQuestion: clearUsefulQuestion
        ? null
        : usefulQuestion ?? this.usefulQuestion,
    adaptationReceipt: adaptationReceipt ?? this.adaptationReceipt,
    origin: origin ?? this.origin,
    languageCode: languageCode ?? this.languageCode,
    userContext: userContext ?? this.userContext,
    conversationReply: clearConversationReply
        ? null
        : conversationReply ?? this.conversationReply,
    disposition: disposition ?? this.disposition,
    controls: controls ?? this.controls,
  );

  factory PlannerV2Response.clarification({
    required String whatIHeard,
    required String mattersMost,
    required List<String> verifiedEvidence,
    required String question,
    required PlannerAdaptationReceipt adaptationReceipt,
    required PlannerResponseOrigin origin,
    String languageCode = 'en',
    PlannerUserContext? userContext,
  }) {
    return PlannerV2Response(
      whatIHeard: whatIHeard,
      mattersMost: mattersMost,
      verifiedEvidence: verifiedEvidence,
      options: const <PlannerOption>[],
      recommendedKind: PlannerOptionKind.minimum,
      recommendationReason: '',
      nextStep: '',
      usefulQuestion: question,
      adaptationReceipt: adaptationReceipt,
      origin: origin,
      languageCode: languageCode,
      userContext: userContext,
      disposition: PlannerResponseDisposition.clarification,
      controls: const <PlannerActionControl>[],
    );
  }

  PlannerV2Response recommend(PlannerOptionKind kind, {required String why}) {
    if (isClarification) {
      throw StateError('A clarification cannot be accepted as a plan.');
    }
    final PlannerOption option = optionByKind[kind]!;
    return copyWith(
      recommendedKind: kind,
      recommendationReason: why,
      nextStep: option.description,
      clearConversationReply: true,
    );
  }

  bool get isSpanish =>
      languageCode.toLowerCase().split(RegExp('[-_]')).first == 'es';

  String _text(String english, String spanish) => isSpanish ? spanish : english;

  String _duration(int minutes) => isSpanish
      ? '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}'
      : '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';

  String _optionDuration(PlannerOption option) {
    final int? seconds = option.estimatedSeconds;
    if (seconds != null && seconds < 60) {
      return isSpanish
          ? '$seconds ${seconds == 1 ? 'segundo' : 'segundos'}'
          : '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    }
    return _duration(option.estimatedMinutes);
  }

  /// The visible conversation answers the person without replaying every option.
  String toConversationText() {
    if (conversationReply?.trim().isNotEmpty ?? false) {
      return conversationReply!.trim();
    }
    final List<String> paragraphs = <String>[whatIHeard.trim()];
    if (!isClarification) {
      paragraphs.add(
        '$nextStep ${_text('Allow up to', 'Dedica como máximo')} ${_optionDuration(recommendedOption)}.',
      );
      paragraphs.add(recommendationReason.trim());
    }
    final String question = usefulQuestion?.trim() ?? '';
    if (question.isNotEmpty) paragraphs.add(question);
    return paragraphs
        .where((String value) => value.isNotEmpty)
        .toSet()
        .join('\n\n');
  }

  /// Summary speech uses only the current action, duration and reason.
  String toSpokenSummary() {
    if (conversationReply?.trim().isNotEmpty ?? false) {
      return conversationReply!.trim();
    }
    if (isClarification) return toConversationText();
    return <String>[
      nextStep.trim(),
      '${_text('Allow up to', 'Dedica como máximo')} ${_optionDuration(recommendedOption)}.',
      recommendationReason.trim(),
    ].where((String value) => value.isNotEmpty).toSet().join(' ');
  }

  /// The complete, inspectable version includes the same costs as the cards.
  String toAccessibleText() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('${_text('What I heard', 'Lo que entendí')}: $whatIHeard')
      ..writeln(
        '${_text('What matters most', 'Lo más importante')}: $mattersMost',
      );
    if (isClarification) {
      buffer.writeln(
        '${_text('Clarifying question', 'Para aclararlo')}: ${usefulQuestion!.trim()}',
      );
      return buffer.toString().trim();
    }
    buffer.writeln(_text('Plan options:', 'Opciones del plan:'));
    for (final PlannerOption option in options) {
      buffer.writeln(
        '${_kindLabel(option.kind)}: ${option.title}. ${_optionDuration(option)}. ${option.description} ${_text('Tradeoff', 'Lo que implica')}: ${option.tradeoff}',
      );
    }
    buffer
      ..writeln(
        '${_text('Recommended', 'Recomendado')}: ${recommendedOption.title}',
      )
      ..writeln('${_text('Why', 'Por qué')}: $recommendationReason')
      ..writeln('${_text('Next step', 'Siguiente paso')}: $nextStep');
    final String question = usefulQuestion?.trim() ?? '';
    if (question.isNotEmpty) {
      buffer.writeln(
        '${_text('Useful question', 'Una pregunta útil')}: $question',
      );
    }
    buffer.writeln(_text('Evidence:', 'Evidencia:'));
    for (final String item in verifiedEvidence) {
      buffer.writeln('• $item');
    }
    return buffer.toString().trim();
  }

  void _validate() {
    if (verifiedEvidence.isEmpty) {
      throw ArgumentError.value(
        verifiedEvidence,
        'verifiedEvidence',
        'Planner V2 responses require explicit evidence.',
      );
    }
    if (isClarification) {
      final String question = usefulQuestion?.trim() ?? '';
      if (options.isNotEmpty ||
          controls.isNotEmpty ||
          recommendationReason.trim().isNotEmpty ||
          nextStep.trim().isNotEmpty) {
        throw ArgumentError(
          'Clarification responses cannot contain plan options or actions.',
        );
      }
      if (question.isEmpty || '?'.allMatches(question).length != 1) {
        throw ArgumentError.value(
          usefulQuestion,
          'usefulQuestion',
          'Clarification responses require exactly one question.',
        );
      }
      return;
    }
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
    if (controls.toSet().length != PlannerActionControl.values.length ||
        !controls.toSet().containsAll(PlannerActionControl.values)) {
      throw ArgumentError.value(
        controls,
        'controls',
        'Planner V2 responses require all explicit action controls.',
      );
    }
  }

  String _kindLabel(PlannerOptionKind kind) => switch (kind) {
    PlannerOptionKind.minimum => _text('Minimum', 'Mínimo'),
    PlannerOptionKind.bestFit => _text('Best-fit', 'Más adecuado'),
    PlannerOptionKind.stretch => _text('Stretch', 'Más esfuerzo'),
  };
}
