/// CHRONOSPARK-CLASS: SHIPPING | Feature: Axiomara assistant orchestration
enum AxiomaraRoute { local, si, safety, claude, hybrid }

final class AxiomaraRouteDecision {
  const AxiomaraRouteDecision({
    required this.route,
    required this.reason,
    required this.externalAiSelected,
    required this.requiresCredits,
    required this.readOnly,
  });

  final AxiomaraRoute route;
  final String reason;

  /// Route intent only. Actual provider use belongs in the execution receipt.
  final bool externalAiSelected;
  final bool requiresCredits;
  final bool readOnly;

  void validate() {
    if (reason.trim().isEmpty) {
      throw const AxiomaraRouterContractException(
        'A routing decision requires a reason.',
      );
    }
    final bool externalRoute =
        route == AxiomaraRoute.claude || route == AxiomaraRoute.hybrid;
    if (externalAiSelected != externalRoute ||
        requiresCredits != externalRoute) {
      throw const AxiomaraRouterContractException(
        'External AI and credit flags must match the selected route.',
      );
    }
  }
}

final class AxiomaraRouteReceipt {
  const AxiomaraRouteReceipt({
    required this.decision,
    required this.memoryContextCount,
    required this.latencyMs,
    this.externalAiUsed = false,
    this.creditsUsed = 0,
  });

  final AxiomaraRouteDecision decision;
  final int memoryContextCount;
  final int latencyMs;

  /// True only after an actual model-backed response is confirmed.
  final bool externalAiUsed;
  final int creditsUsed;

  void validate() {
    decision.validate();
    if (memoryContextCount < 0 || latencyMs < 0 || creditsUsed < 0) {
      throw const AxiomaraRouterContractException(
        'Route receipt counters cannot be negative.',
      );
    }
    if ((externalAiUsed && !decision.externalAiSelected) ||
        (creditsUsed != 0 && !externalAiUsed)) {
      throw const AxiomaraRouterContractException(
        'Actual external AI use and credits require a selected, completed model route.',
      );
    }
  }
}

abstract interface class AxiomaraRouterPort {
  Future<AxiomaraRouteDecision> route({
    required String accountScopeId,
    required String input,
    required bool externalAiAllowed,
  });
}

final class AxiomaraRouterContractException implements Exception {
  const AxiomaraRouterContractException(this.message);
  final String message;
  @override
  String toString() => 'AxiomaraRouterContractException: $message';
}
