// lib/engine/si/si_cognitive_coherence_validator.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum CoherenceSeverity { info, warning, critical }

class CoherenceIssue {
  const CoherenceIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final CoherenceSeverity severity;
}

class CoherenceReport {
  const CoherenceReport({
    required this.coherent,
    required this.score,
    required this.issues,
    required this.recommendation,
  });

  final bool coherent;
  final double score;
  final List<CoherenceIssue> issues;
  final String recommendation;

  bool get hasCritical => issues.any(
    (CoherenceIssue i) => i.severity == CoherenceSeverity.critical,
  );
}

class SICognitiveCoherenceValidator {
  const SICognitiveCoherenceValidator();

  CoherenceReport validate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SICognitionState cognition,
    SIDecision? decision,
    SIResponse? response,
  }) {
    final List<CoherenceIssue> issues = <CoherenceIssue>[];

    final double intentConfidence = siClamp01(intent.confidence);
    final double risk = siClamp01(cognition.meta.misunderstandingRisk);
    final String mood = siNormalizeMood(context.userState.emotion);

    if (intentConfidence < 0.45 && !cognition.meta.askClarification) {
      issues.add(
        const CoherenceIssue(
          code: 'low_confidence_without_clarification',
          message: 'Low intent confidence should trigger clarification.',
          severity: CoherenceSeverity.warning,
        ),
      );
    }

    if (risk >= 0.7 && decision?.action != 'respond_conversationally') {
      issues.add(
        const CoherenceIssue(
          code: 'high_risk_direct_action',
          message: 'High misunderstanding risk should avoid direct action.',
          severity: CoherenceSeverity.warning,
        ),
      );
    }

    if (instinct.safetyFirst &&
        !(cognition.meta.slowDown || cognition.meta.adjustTone)) {
      issues.add(
        const CoherenceIssue(
          code: 'safety_without_tone_adjustment',
          message: 'Safety-first instinct should slow down or adjust tone.',
          severity: CoherenceSeverity.warning,
        ),
      );
    }

    if (decision != null && !decision.safe) {
      issues.add(
        const CoherenceIssue(
          code: 'unsafe_decision',
          message: 'Decision contains ethics flags and should be constrained.',
          severity: CoherenceSeverity.critical,
        ),
      );
    }

    if (response != null) {
      final String message = response.message.toLowerCase();

      if ((mood == 'stressed' || instinct.avoidOverwhelm) &&
          (message.contains('you must') || message.contains('have to'))) {
        issues.add(
          const CoherenceIssue(
            code: 'pressure_language',
            message:
                'Pressure language conflicts with stressed/overwhelmed state.',
            severity: CoherenceSeverity.warning,
          ),
        );
      }

      if (instinct.avoidOverwhelm && response.message.length > 320) {
        issues.add(
          const CoherenceIssue(
            code: 'overlong_overwhelm_response',
            message: 'Overwhelmed state should receive shorter responses.',
            severity: CoherenceSeverity.warning,
          ),
        );
      }

      if (response.task == null && response.message.contains('"')) {
        issues.add(
          const CoherenceIssue(
            code: 'possible_unverified_task_reference',
            message:
                'Response may imply a specific task without a task object.',
            severity: CoherenceSeverity.info,
          ),
        );
      }
    }

    final double score = _score(issues);
    return CoherenceReport(
      coherent:
          score >= 0.72 &&
          !issues.any(
            (CoherenceIssue i) => i.severity == CoherenceSeverity.critical,
          ),
      score: score,
      issues: List<CoherenceIssue>.unmodifiable(issues),
      recommendation: _recommendation(score, issues),
    );
  }

  double _score(List<CoherenceIssue> issues) {
    if (issues.isEmpty) return 1.0;

    double penalty = 0;
    for (final CoherenceIssue issue in issues) {
      switch (issue.severity) {
        case CoherenceSeverity.info:
          penalty += 0.06;
          break;
        case CoherenceSeverity.warning:
          penalty += 0.18;
          break;
        case CoherenceSeverity.critical:
          penalty += 0.42;
          break;
      }
    }

    return siClamp01(1.0 - penalty, fallback: 0.5);
  }

  String _recommendation(double score, List<CoherenceIssue> issues) {
    if (issues.any(
      (CoherenceIssue i) => i.severity == CoherenceSeverity.critical,
    )) {
      return 'Use safe fallback response before showing output.';
    }
    if (score < 0.72) return 'Clarify, shorten, and soften before responding.';
    if (score < 0.9) return 'Response is usable with minor caution.';
    return 'Response is coherent.';
  }
}
