import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';

/// Conservative first-pass router. It never sends data to an external model;
/// it only classifies the route that a later orchestration boundary may use.
final class AxiomaraDeterministicRouter implements AxiomaraRouterPort {
  const AxiomaraDeterministicRouter();

  @override
  Future<AxiomaraRouteDecision> route({
    required String accountScopeId,
    required String input,
    required bool externalAiAllowed,
  }) async {
    if (accountScopeId.trim().isEmpty || input.trim().isEmpty) {
      throw const AxiomaraRouterContractException(
        'Routing requires account scope and non-empty input.',
      );
    }

    final String text = input.trim().toLowerCase();
    final AxiomaraRouteDecision decision;

    if (_isLocalRetrieval(text)) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.local,
        reason: 'deterministic_retrieval_or_navigation',
        externalAiUsed: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else if (_isEvidenceDecision(text) || !externalAiAllowed) {
      decision = AxiomaraRouteDecision(
        route: AxiomaraRoute.si,
        reason: externalAiAllowed
            ? 'evidence_based_decision'
            : 'external_ai_not_allowed',
        externalAiUsed: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else if (_needsGroundedExplanation(text)) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.hybrid,
        reason: 'grounded_complex_reasoning',
        externalAiUsed: true,
        requiresCredits: true,
        readOnly: true,
      );
    } else {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.claude,
        reason: 'general_complex_language_reasoning',
        externalAiUsed: true,
        requiresCredits: true,
        readOnly: true,
      );
    }

    decision.validate();
    return decision;
  }

  bool _isLocalRetrieval(String text) =>
      RegExp(r'^(show|list|open|view)\b').hasMatch(text) ||
      text.startsWith('what is due') ||
      text.startsWith("what's due") ||
      text.startsWith('what is scheduled');

  bool _isEvidenceDecision(String text) =>
      text.contains('highest priority') ||
      text.contains('what should i do next') ||
      text.contains('what needs attention') ||
      text.contains('which task') ||
      text.contains('deadline') ||
      text.contains('overdue');

  bool _needsGroundedExplanation(String text) =>
      text.contains('why do i') ||
      text.contains('why am i') ||
      text.contains('help me understand') ||
      text.contains('figure out why') ||
      text.contains('based on my tasks') ||
      text.contains('based on my goals');
}
