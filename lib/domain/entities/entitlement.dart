/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
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

  bool isExpiredAt(DateTime reference) =>
      expiresAt != null && reference.isAfter(expiresAt!);

  bool get isExpired => isExpiredAt(DateTime.now());

  bool hasAccessAt(DateTime reference) => isEntitled && !isExpiredAt(reference);

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

  void validate({DateTime? now}) {
    if (isEntitled && isExpiredAt(now ?? DateTime.now())) {
      throw StateError('Entitlement cannot be active and expired');
    }
  }
}
