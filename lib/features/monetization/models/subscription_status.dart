class SubscriptionStatus {
  const SubscriptionStatus({
    required this.planId,
    required this.productId,
    required this.status,
    required this.source,
    required this.isActive,
    required this.isPremium,
    required this.autoRenews,
    required this.periodCredits,
    this.startedAt,
    this.expiresAt,
    this.updatedAt,
  });

  final String planId;
  final String? productId;
  final String status;
  final String source;
  final bool isActive;
  final bool isPremium;
  final bool autoRenews;
  final int periodCredits;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  bool get isLifetime => planId == 'lifetime' && isActive;

  static SubscriptionStatus free() {
    return const SubscriptionStatus(
      planId: 'free',
      productId: null,
      status: 'free',
      source: 'default',
      isActive: false,
      isPremium: false,
      autoRenews: false,
      periodCredits: 20,
    );
  }

  factory SubscriptionStatus.fromMap(Map<String, dynamic> map) {
    final String planId = map['plan_id']?.toString() ?? 'free';
    final String status = map['status']?.toString() ?? 'free';
    final bool isActive = map['is_active'] == true || status == 'active';
    return SubscriptionStatus(
      planId: planId,
      productId: map['product_id']?.toString(),
      status: status,
      source: map['source']?.toString() ?? 'supabase',
      isActive: isActive,
      isPremium: planId != 'free' && isActive,
      autoRenews: map['auto_renews'] == true,
      periodCredits: (map['period_credits'] as num?)?.toInt() ??
          (planId == 'premium_monthly'
              ? 250
              : planId == 'premium_yearly'
                  ? 4000
                  : 20),
      startedAt: DateTime.tryParse(map['started_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}