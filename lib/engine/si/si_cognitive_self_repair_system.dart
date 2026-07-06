// lib/engine/si/si_cognitive_self_repair_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum RepairSeverity { none, minor, major, critical }

class RepairIssue {
  const RepairIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final RepairSeverity severity;
}

class CognitiveRepairPlan {
  const CognitiveRepairPlan({
    required this.healthy,
    required this.severity,
    required this.issues,
    required this.repairedMessage,
    required this.repairedAction,
    required this.confidence,
  });

  final bool healthy;
  final RepairSeverity severity;
  final List<RepairIssue> issues;
  final String repairedMessage;
  final String repairedAction;
  final double confidence;
}

class SICognitiveSelfRepairSystem {
  const SICognitiveSelfRepairSystem();

  CognitiveRepairPlan inspectAndRepair({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    SIDecision? decision,
    SIResponse? response,
  }) {
    final List<RepairIssue> issues = <RepairIssue>[];

    final String message = siClean(
      response?.message ?? decision?.reasoning ?? cognition?.summary,
    );

    final double confidence = siClamp01(
      response?.confidence ?? decision?.confidence ?? intent.confidence,
    );

    if (message.isEmpty) {
      issues.add(
        const RepairIssue(
          code: 'empty_output',
          message: 'Output is empty.',
          severity: RepairSeverity.major,
        ),
      );
    }

    if (message.length > 520) {
      issues.add(
        const RepairIssue(
          code: 'output_too_long',
          message: 'Output exceeds safe cognitive length.',
          severity: RepairSeverity.minor,
        ),
      );
    }

    if (confidence < 0.35 && !(cognition?.meta.askClarification ?? false)) {
      issues.add(
        const RepairIssue(
          code: 'low_confidence_no_repair',
          message: 'Low confidence should trigger clarification or fallback.',
          severity: RepairSeverity.major,
        ),
      );
    }

    if (decision != null && !decision.safe) {
      issues.add(
        const RepairIssue(
          code: 'unsafe_decision',
          message: 'Decision failed safety assessment.',
          severity: RepairSeverity.critical,
        ),
      );
    }

    if (instinct.safetyFirst &&
        RegExp(
          r'\b(must|urgent|now|have to)\b',
          caseSensitive: false,
        ).hasMatch(message)) {
      issues.add(
        const RepairIssue(
          code: 'unsafe_pressure',
          message: 'Safety-first output contains pressure language.',
          severity: RepairSeverity.major,
        ),
      );
    }

    final RepairSeverity severity = _maxSeverity(issues);

    return CognitiveRepairPlan(
      healthy: issues.isEmpty,
      severity: severity,
      issues: List<RepairIssue>.unmodifiable(issues),
      repairedMessage: _repairMessage(
        message: message,
        severity: severity,
        instinct: instinct,
      ),
      repairedAction: _repairAction(
        severity: severity,
        decision: decision,
        cognition: cognition,
      ),
      confidence: _repairConfidence(confidence, severity),
    );
  }

  RepairSeverity _maxSeverity(List<RepairIssue> issues) {
    if (issues.any(
      (RepairIssue issue) => issue.severity == RepairSeverity.critical,
    )) {
      return RepairSeverity.critical;
    }
    if (issues.any(
      (RepairIssue issue) => issue.severity == RepairSeverity.major,
    )) {
      return RepairSeverity.major;
    }
    if (issues.any(
      (RepairIssue issue) => issue.severity == RepairSeverity.minor,
    )) {
      return RepairSeverity.minor;
    }
    return RepairSeverity.none;
  }

  String _repairMessage({
    required String message,
    required RepairSeverity severity,
    required InstinctGuidance instinct,
  }) {
    if (severity == RepairSeverity.critical) {
      return 'Let’s pause and take a safer path. Choose one small, clear next step.';
    }

    String output = siClean(
      message,
      fallback: 'Tell me the task or goal you want help with.',
    );

    output = output
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could');

    final int maxChars = instinct.avoidOverwhelm || instinct.safetyFirst
        ? 220
        : 360;
    return _truncate(output, maxChars);
  }

  String _repairAction({
    required RepairSeverity severity,
    SIDecision? decision,
    SICognitionState? cognition,
  }) {
    if (severity == RepairSeverity.critical) return 'respond_conversationally';
    if (severity == RepairSeverity.major &&
        (cognition?.meta.askClarification ?? false)) {
      return 'ask_clarification';
    }
    return decision?.action ?? 'respond_conversationally';
  }

  double _repairConfidence(double confidence, RepairSeverity severity) {
    switch (severity) {
      case RepairSeverity.none:
        return siClamp01(confidence);
      case RepairSeverity.minor:
        return siClamp01(confidence * 0.9);
      case RepairSeverity.major:
        return siClamp01(confidence * 0.65);
      case RepairSeverity.critical:
        return 0.25;
    }
  }

  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    final String cut = text.substring(0, maxChars).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
