class Entitlement {
  const Entitlement({
    required this.featureId,
    required this.isEntitled,
    required this.source,
    this.expiresAt,
  });

  final String featureId;
  final bool isEntitled;
  final String source;
  final DateTime? expiresAt;
}
