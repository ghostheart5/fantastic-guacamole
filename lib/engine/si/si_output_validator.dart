import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';

class SIOutputValidationResult {
  const SIOutputValidationResult({
    required this.accepted,
    required this.response,
    required this.violations,
  });

  final bool accepted;
  final SIResponse response;
  final List<String> violations;
}

/// The single terminal gate for every SI response leaving the engine facade.
class SIOutputValidator {
  const SIOutputValidator();

  bool accepts({
    required String message,
    required double confidence,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
    bool decisionSafe = true,
    bool decisionPolicyApplied = true,
  }) {
    return _violations(
      message: message,
      confidence: confidence,
      coherent: coherent,
      deduped: deduped,
      policyAccepted: policyAccepted,
      grounded: grounded,
      decisionSafe: decisionSafe,
      decisionPolicyApplied: decisionPolicyApplied,
    ).isEmpty;
  }

  SIOutputValidationResult validate({
    required SIResponse response,
    required SIDecision decision,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
  }) {
    final List<String> violations = _violations(
      message: response.message,
      confidence: response.confidence,
      coherent: coherent,
      deduped: deduped,
      policyAccepted: policyAccepted,
      grounded: grounded,
      decisionSafe: decision.safe,
      decisionPolicyApplied: decision.policyApplied,
    );
    if (violations.isEmpty) {
      return SIOutputValidationResult(
        accepted: true,
        response: response,
        violations: const <String>[],
      );
    }

    return SIOutputValidationResult(
      accepted: false,
      response: SIResponse(
        message:
            'I could not validate that response against current state. '
            'Tell me the task or goal, and I will help with one grounded next step.',
        emotion: 'balanced',
        persona: response.persona,
        traits: response.traits,
        confidence: 0.5,
        task: response.task,
      ),
      violations: List<String>.unmodifiable(violations),
    );
  }

  List<String> _violations({
    required String message,
    required double confidence,
    required bool coherent,
    required bool deduped,
    required bool policyAccepted,
    required bool grounded,
    required bool decisionSafe,
    required bool decisionPolicyApplied,
  }) {
    final List<String> violations = <String>[];
    final String text = message.trim();
    if (text.isEmpty) violations.add('empty_message');
    if (!confidence.isFinite || confidence < 0.3 || confidence > 1) {
      violations.add('invalid_confidence');
    }
    if (text.isNotEmpty && !isPolicyAcceptableResponse(text)) {
      violations.add('response_policy_rejected');
    }
    if (!decisionSafe) violations.add('unsafe_decision');
    if (!decisionPolicyApplied) violations.add('decision_policy_not_applied');
    if (!coherent) violations.add('incoherent');
    if (!deduped) violations.add('duplicate');
    if (!policyAccepted) violations.add('caller_policy_rejected');
    if (!grounded) violations.add('ungrounded');
    return violations;
  }
}
