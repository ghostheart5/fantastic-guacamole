// lib/engine/si/si_cognitive_dissonance_resolver.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum DissonanceLevel { none, mild, moderate, severe }

class DissonanceFinding {
  const DissonanceFinding({
    required this.code,
    required this.message,
    required this.weight,
  });

  final String code;
  final String message;
  final double weight;
}

class DissonanceResolution {
  const DissonanceResolution({
    required this.level,
    required this.score,
    required this.findings,
    required this.recommendedAction,
    required this.adjustedMessage,
    required this.shouldAskClarification,
    required this.shouldUseSafeFallback,
  });

  final DissonanceLevel level;
  final double score;
  final List<DissonanceFinding> findings;
  final String recommendedAction;
  final String adjustedMessage;
  final bool shouldAskClarification;
  final bool shouldUseSafeFallback;
}

class SICognitiveDissonanceResolver {
  const SICognitiveDissonanceResolver();

  DissonanceResolution resolve({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SICognitionState cognition,
    SIDecision? decision,
    SIResponse? response,
  }) {
    final List<DissonanceFinding> findings = <DissonanceFinding>[];

    final double confidence = siClamp01(intent.confidence);
    final double risk = siClamp01(cognition.meta.misunderstandingRisk);
    final String mood = siNormalizeMood(context.userState.emotion);
    final String message = siClean(response?.message ?? decision?.reasoning);

    if (confidence < 0.45 && !cognition.meta.askClarification) {
      findings.add(
        const DissonanceFinding(
          code: 'low_confidence_no_clarification',
          message: 'Low confidence conflicts with direct guidance.',
          weight: 0.22,
        ),
      );
    }

    if (risk > 0.7 && decision?.action != 'respond_conversationally') {
      findings.add(
        const DissonanceFinding(
          code: 'high_risk_action',
          message:
              'High misunderstanding risk conflicts with action execution.',
          weight: 0.25,
        ),
      );
    }

    if (instinct.safetyFirst && message.length > 260) {
      findings.add(
        const DissonanceFinding(
          code: 'safety_long_output',
          message: 'Safety-first mode conflicts with long output.',
          weight: 0.18,
        ),
      );
    }

    if ((mood == 'stressed' || instinct.avoidOverwhelm) &&
        RegExp(
          r'\b(you must|have to|should)\b',
          caseSensitive: false,
        ).hasMatch(message)) {
      findings.add(
        const DissonanceFinding(
          code: 'pressure_language',
          message: 'Pressure language conflicts with user state.',
          weight: 0.2,
        ),
      );
    }

    if (decision != null && !decision.safe) {
      findings.add(
        const DissonanceFinding(
          code: 'unsafe_decision',
          message: 'Unsafe decision conflicts with output eligibility.',
          weight: 0.4,
        ),
      );
    }

    final double score = siClamp01(
      findings.fold<double>(
        0,
        (double sum, DissonanceFinding finding) => sum + finding.weight,
      ),
      fallback: 0,
    );

    final DissonanceLevel level = _level(score);
    final bool safeFallback =
        level == DissonanceLevel.severe ||
        findings.any((DissonanceFinding finding) {
          return finding.code == 'unsafe_decision';
        });

    return DissonanceResolution(
      level: level,
      score: score,
      findings: List<DissonanceFinding>.unmodifiable(findings),
      recommendedAction: _recommendedAction(level, intent, safeFallback),
      adjustedMessage: _adjust(
        message: message,
        instinct: instinct,
        safeFallback: safeFallback,
      ),
      shouldAskClarification:
          confidence < 0.5 || risk > 0.65 || level == DissonanceLevel.moderate,
      shouldUseSafeFallback: safeFallback,
    );
  }

  DissonanceLevel _level(double score) {
    if (score <= 0.05) return DissonanceLevel.none;
    if (score < 0.28) return DissonanceLevel.mild;
    if (score < 0.55) return DissonanceLevel.moderate;
    return DissonanceLevel.severe;
  }

  String _recommendedAction(
    DissonanceLevel level,
    SIIntent intent,
    bool safeFallback,
  ) {
    if (safeFallback) return 'respond_conversationally';
    if (level == DissonanceLevel.moderate) return 'ask_clarification';
    return intent.primary.label;
  }

  String _adjust({
    required String message,
    required InstinctGuidance instinct,
    required bool safeFallback,
  }) {
    if (safeFallback) {
      return 'Let’s take a safer route. I’ll keep this simple: choose one small next step.';
    }

    String output = siClean(
      message,
      fallback: 'Tell me what you want to work on.',
    );

    output = output
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could');

    final int limit = instinct.avoidOverwhelm || instinct.safetyFirst
        ? 220
        : 360;
    return _truncate(output, limit);
  }

  String _truncate(String text, int maxChars) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;

    final String cut = clean.substring(0, maxChars).trim();
    final int punctuation = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (punctuation > 80) return cut.substring(0, punctuation + 1);

    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
