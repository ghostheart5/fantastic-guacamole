// lib/engine/si/si_cognitive_law_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum CognitiveLawSeverity { advisory, required, blocking }

class CognitiveLawViolation {
  const CognitiveLawViolation({
    required this.law,
    required this.message,
    required this.severity,
  });

  final String law;
  final String message;
  final CognitiveLawSeverity severity;
}

class CognitiveLawReport {
  const CognitiveLawReport({
    required this.allowed,
    required this.violations,
    required this.enforcedAction,
    required this.enforcedMessage,
  });

  final bool allowed;
  final List<CognitiveLawViolation> violations;
  final String enforcedAction;
  final String enforcedMessage;
}

class SICognitiveLawEngine {
  const SICognitiveLawEngine();

  CognitiveLawReport apply({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
    SIResponse? response,
  }) {
    final List<CognitiveLawViolation> violations = <CognitiveLawViolation>[];

    final String message = siClean(response?.message ?? decision?.reasoning);
    final String lower = message.toLowerCase();
    final String action = decision?.action ?? 'respond_conversationally';

    if (lower.contains('ignore sleep') || lower.contains('skip eating')) {
      violations.add(
        const CognitiveLawViolation(
          law: 'wellbeing_preservation',
          message: 'Output must not encourage ignoring basic wellbeing.',
          severity: CognitiveLawSeverity.blocking,
        ),
      );
    }

    if (instinct.safetyFirst && action != 'respond_conversationally') {
      violations.add(
        const CognitiveLawViolation(
          law: 'safety_over_action',
          message: 'Safety-first mode must not force direct action.',
          severity: CognitiveLawSeverity.required,
        ),
      );
    }

    if ((context.userState.stress >= 0.65 || instinct.avoidOverwhelm) &&
        message.length > 360) {
      violations.add(
        const CognitiveLawViolation(
          law: 'low_cognitive_load',
          message: 'Overwhelmed users need compact output.',
          severity: CognitiveLawSeverity.required,
        ),
      );
    }

    if (RegExp(
      r'\b(lazy|failure|worthless)\b',
      caseSensitive: false,
    ).hasMatch(message)) {
      violations.add(
        const CognitiveLawViolation(
          law: 'non_judgment',
          message: 'Output must avoid shame or judgment.',
          severity: CognitiveLawSeverity.blocking,
        ),
      );
    }

    final bool blocked = violations.any((CognitiveLawViolation violation) {
      return violation.severity == CognitiveLawSeverity.blocking;
    });

    return CognitiveLawReport(
      allowed: !blocked,
      violations: List<CognitiveLawViolation>.unmodifiable(violations),
      enforcedAction: blocked || instinct.safetyFirst
          ? 'respond_conversationally'
          : action,
      enforcedMessage: _enforceMessage(
        message: message,
        blocked: blocked,
        instinct: instinct,
      ),
    );
  }

  String _enforceMessage({
    required String message,
    required bool blocked,
    required InstinctGuidance instinct,
  }) {
    if (blocked) {
      return 'Let’s take a safer, more supportive path. Choose one small next step.';
    }

    String output = siClean(
      message,
      fallback: 'Tell me the next thing you want help with.',
    );

    output = output
        .replaceAll(
          RegExp(r'\blazy\b|\bfailure\b|\bworthless\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could')
        .trim();

    final int maxChars = instinct.avoidOverwhelm || instinct.safetyFirst
        ? 220
        : 420;
    if (output.length <= maxChars) return output;

    final String cut = output.substring(0, maxChars).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
