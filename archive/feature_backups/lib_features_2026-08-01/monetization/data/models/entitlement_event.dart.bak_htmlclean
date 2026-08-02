class EntitlementEvent {
  const EntitlementEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.isActive,
    this.planId,
    this.productId,
    this.effectiveAt,
    this.expiresAt,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String eventType;
  final bool isActive;
  final String? planId;
  final String? productId;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  EntitlementEvent copyWith({
    String? id,
    String? userId,
    String? eventType,
    bool? isActive,
    String? planId,
    String? productId,
    DateTime? effectiveAt,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return EntitlementEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      isActive: isActive ?? this.isActive,
      planId: planId ?? this.planId,
      productId: productId ?? this.productId,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      expiresAt: expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EntitlementEvent.fromJson(Map<String, dynamic> json) {
    return EntitlementEvent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'unknown',
      isActive: json['is_active'] == true,
      planId: json['plan_id']?.toString(),
      productId: json['product_id']?.toString(),
      effectiveAt: _parseDateTime(json['effective_at']),
      expiresAt: _parseDateTime(json['expires_at']),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'is_active': isActive,
      'plan_id': planId,
      'product_id': productId,
      'effective_at': effectiveAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
