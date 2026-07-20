class AiCreditPurchase {
  const AiCreditPurchase({
    required this.id,
    required this.productId,
    required this.purchaseType,
    required this.platform,
    required this.purchaseState,
    required this.creditsGranted,
    required this.createdAt,
    this.orderId,
    this.purchaseTokenHash,
    this.subscriptionPlanId,
    this.verifiedAt,
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final String productId;
  final String purchaseType;
  final String platform;
  final String purchaseState;
  final int creditsGranted;
  final DateTime createdAt;
  final String? orderId;
  final String? purchaseTokenHash;
  final String? subscriptionPlanId;
  final DateTime? verifiedAt;
  final Map<String, dynamic> payload;

  factory AiCreditPurchase.fromMap(Map<String, dynamic> map) {
    return AiCreditPurchase(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      purchaseType: map['purchase_type']?.toString() ?? 'inapp',
      platform: map['platform']?.toString() ?? 'google_play',
      purchaseState: map['purchase_state']?.toString() ?? 'unknown',
      creditsGranted: (map['credits_granted'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      orderId: map['order_id']?.toString(),
      purchaseTokenHash: map['purchase_token_hash']?.toString(),
      subscriptionPlanId: map['subscription_plan_id']?.toString(),
      verifiedAt: DateTime.tryParse(map['verified_at']?.toString() ?? ''),
      payload:
          (map['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}