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

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get hasAccess => isEntitled && !isExpired;

  Entitlement grant() => Entitlement(
    featureId: featureId,
    isEntitled: true,
    source: source,
    expiresAt: expiresAt,
  );

  Entitlement revoke() => Entitlement(
    featureId: featureId,
    isEntitled: false,
    source: source,
    expiresAt: expiresAt,
  );

  void validate() {
    if (isEntitled && isExpired) {
      throw StateError('Entitlement cannot be active and expired');
    }
  }
}
