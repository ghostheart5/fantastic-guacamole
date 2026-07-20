class AiCreditPurchase {
  const AiCreditPurchase({
    required this.id,
    required this.userId,
    required this.productId,
    required this.purchaseType,
    required this.platform,
    required this.purchaseState,
    required this.creditsGranted,
    this.orderId,
    this.purchaseTokenHash,
    this.subscriptionPlanId,
    this.payload,
    this.verifiedAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String productId;
  final String purchaseType;
  final String platform;
  final String purchaseState;
  final int creditsGranted;
  final String? orderId;
  final String? purchaseTokenHash;
  final String? subscriptionPlanId;
  final Map<String, dynamic>? payload;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  AiCreditPurchase copyWith({
    String? id,
    String? userId,
    String? productId,
    String? purchaseType,
    String? platform,
    String? purchaseState,
    int? creditsGranted,
    String? orderId,
    String? purchaseTokenHash,
    String? subscriptionPlanId,
    Map<String, dynamic>? payload,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) {
    return AiCreditPurchase(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      purchaseType: purchaseType ?? this.purchaseType,
      platform: platform ?? this.platform,
      purchaseState: purchaseState ?? this.purchaseState,
      creditsGranted: creditsGranted ?? this.creditsGranted,
      orderId: orderId ?? this.orderId,
      purchaseTokenHash: purchaseTokenHash ?? this.purchaseTokenHash,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      payload: payload ?? this.payload,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AiCreditPurchase.fromJson(Map<String, dynamic> json) {
    return AiCreditPurchase(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      purchaseType: json['purchase_type']?.toString() ?? 'inapp',
      platform: json['platform']?.toString() ?? 'google_play',
      purchaseState: json['purchase_state']?.toString() ?? 'unknown',
      creditsGranted: (json['credits_granted'] as num?)?.toInt() ?? 0,
      orderId: json['order_id']?.toString(),
      purchaseTokenHash: json['purchase_token_hash']?.toString(),
      subscriptionPlanId: json['subscription_plan_id']?.toString(),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
      verifiedAt: _parseDateTime(json['verified_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'purchase_type': purchaseType,
      'platform': platform,
      'purchase_state': purchaseState,
      'credits_granted': creditsGranted,
      'order_id': orderId,
      'purchase_token_hash': purchaseTokenHash,
      'subscription_plan_id': subscriptionPlanId,
      'payload': payload,
      'verified_at': verifiedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
