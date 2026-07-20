enum EntitlementTier { free, premium, ultimate }

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.isPremium,
    required this.isActive,
    required this.planId,
    required this.source,
    this.expiresAt,
    this.status,
  });

  final bool isPremium;
  final bool isActive;
  final String planId;
  final String source;
  final DateTime? expiresAt;
  final String? status;

  EntitlementTier get tier {
    final String normalizedPlan = planId.trim().toLowerCase();
    if (!isPremium || !isActive || normalizedPlan.isEmpty || normalizedPlan == 'free') {
      return EntitlementTier.free;
    }
    if (normalizedPlan == 'ultimate' || normalizedPlan == 'lifetime') {
      return EntitlementTier.ultimate;
    }
    return EntitlementTier.premium;
  }

  PremiumEntitlement copyWith({
    bool? isPremium,
    bool? isActive,
    String? planId,
    String? source,
    DateTime? expiresAt,
    String? status,
  }) {
    return PremiumEntitlement(
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      planId: planId ?? this.planId,
      source: source ?? this.source,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  factory PremiumEntitlement.fromJson(Map<String, dynamic> json) {
    return PremiumEntitlement(
      isPremium: json['is_premium'] == true,
      isActive: json['is_active'] == true,
      planId: json['plan_id']?.toString() ?? 'free',
      source: json['source']?.toString() ?? 'supabase',
      expiresAt: _parseDateTime(json['expires_at']),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'is_premium': isPremium,
      'is_active': isActive,
      'plan_id': planId,
      'source': source,
      'expires_at': expiresAt?.toIso8601String(),
      'status': status,
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
