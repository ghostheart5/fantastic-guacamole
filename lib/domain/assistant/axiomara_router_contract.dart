enum AxiomaraRoute { local, si, claude, hybrid }

final class AxiomaraRouteDecision {
  const AxiomaraRouteDecision({
    required this.route,
    required this.reason,
    required this.externalAiUsed,
    required this.requiresCredits,
    required this.readOnly,
  });

  final AxiomaraRoute route;
  final String reason;
  final bool externalAiUsed;
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
    if (externalAiUsed != externalRoute || requiresCredits != externalRoute) {
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
    this.creditsUsed = 0,
  });

  final AxiomaraRouteDecision decision;
  final int memoryContextCount;
  final int latencyMs;
  final int creditsUsed;

  void validate() {
    decision.validate();
    if (memoryContextCount < 0 || latencyMs < 0 || creditsUsed < 0) {
      throw const AxiomaraRouterContractException(
        'Route receipt counters cannot be negative.',
      );
    }
    if (!decision.externalAiUsed && creditsUsed != 0) {
      throw const AxiomaraRouterContractException(
        'Local and SI routes cannot report external AI credit usage.',
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
