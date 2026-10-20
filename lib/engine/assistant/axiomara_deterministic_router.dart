import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';

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

    final String text = _normalizedInput(input);
    final AxiomaraRouteDecision decision;

    if (EmotionalSafetyPolicy.assess(input).route !=
        EmotionalSafetyRoute.routine) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.safety,
        reason: 'emotional_safety_route_required',
        externalAiSelected: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else if (_isEvidenceDecision(text)) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.si,
        reason: 'evidence_based_decision',
        externalAiSelected: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else if (_needsGroundedExplanation(text)) {
      decision = AxiomaraRouteDecision(
        route: externalAiAllowed ? AxiomaraRoute.hybrid : AxiomaraRoute.si,
        reason: externalAiAllowed
            ? 'grounded_complex_reasoning'
            : 'external_ai_not_allowed',
        externalAiSelected: externalAiAllowed,
        requiresCredits: externalAiAllowed,
        readOnly: true,
      );
    } else if (_isLocalRetrieval(text)) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.local,
        reason: 'deterministic_retrieval_or_navigation',
        externalAiSelected: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else if (!externalAiAllowed) {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.si,
        reason: 'external_ai_not_allowed',
        externalAiSelected: false,
        requiresCredits: false,
        readOnly: true,
      );
    } else {
      decision = const AxiomaraRouteDecision(
        route: AxiomaraRoute.claude,
        reason: 'general_complex_language_reasoning',
        externalAiSelected: true,
        requiresCredits: true,
        readOnly: true,
      );
    }

    decision.validate();
    return decision;
  }

  String _normalizedInput(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceFirst(RegExp(r'^[¿¡\s]+'), '');

  bool _isLocalRetrieval(String text) =>
      RegExp(r'^(show|list|open|view)\b').hasMatch(text) ||
      RegExp(
        r'^(muestra|muestrame|ensena|ensename|lista|listar|abre|abrir|ver|consulta)\b',
      ).hasMatch(text) ||
      text.startsWith('what is due') ||
      text.startsWith("what's due") ||
      text.startsWith('what is scheduled') ||
      RegExp(
        r'^what are my (?:tasks|goals|habits|notes|events|appointments)\b',
      ).hasMatch(text) ||
      RegExp(r'^what tasks are due\b').hasMatch(text) ||
      RegExp(
        r'^what (?:tasks|goals|habits|notes) do i have\b',
      ).hasMatch(text) ||
      RegExp(
        r'^cuales son mis (?:tareas|metas|habitos|notas|eventos|citas)\b',
      ).hasMatch(text) ||
      RegExp(r'^que (?:tareas|metas|habitos|notas) tengo\b').hasMatch(text) ||
      RegExp(r'^que tareas vencen\b').hasMatch(text) ||
      text.startsWith('que vence') ||
      text.startsWith('que hay programado');

  bool _isEvidenceDecision(String text) =>
      text.contains('highest priority') ||
      text.contains('what should i do next') ||
      text.contains('what needs attention') ||
      text.contains('which task') ||
      text.contains('deadline') ||
      text.contains('overdue') ||
      text.contains('mayor prioridad') ||
      text.contains('que debo hacer') ||
      text.contains('que deberia hacer') ||
      text.contains('que necesita atencion') ||
      text.contains('cual tarea') ||
      text.contains('fecha limite') ||
      text.contains('vencid');

  bool _needsGroundedExplanation(String text) =>
      text.contains('why do i') ||
      text.contains('why am i') ||
      text.contains('help me understand') ||
      text.contains('figure out why') ||
      text.contains('based on my tasks') ||
      text.contains('based on my goals') ||
      text.contains('por que me') ||
      text.contains('por que estoy') ||
      text.contains('ayudame a entender') ||
      text.contains('basado en mis tareas') ||
      text.contains('basado en mis metas');
}
