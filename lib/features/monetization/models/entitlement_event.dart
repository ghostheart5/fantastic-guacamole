class EntitlementEvent {
  const EntitlementEvent({
    required this.id,
    required this.eventType,
    required this.planId,
    required this.productId,
    required this.isActive,
    required this.effectiveAt,
    required this.createdAt,
    this.expiresAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String eventType;
  final String? planId;
  final String? productId;
  final bool isActive;
  final DateTime effectiveAt;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> metadata;

  factory EntitlementEvent.fromMap(Map<String, dynamic> map) {
    return EntitlementEvent(
      id: map['id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'unknown',
      planId: map['plan_id']?.toString(),
      productId: map['product_id']?.toString(),
      isActive: map['is_active'] == true,
      effectiveAt:
          DateTime.tryParse(map['effective_at']?.toString() ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? ''),
      metadata:
          (map['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}