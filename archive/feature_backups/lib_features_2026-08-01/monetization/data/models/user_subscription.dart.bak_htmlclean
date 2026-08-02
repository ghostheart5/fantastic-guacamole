class UserSubscription {
  const UserSubscription({
    required this.userId,
    required this.planId,
    required this.productId,
    required this.status,
    required this.isActive,
    required this.autoRenews,
    required this.source,
    required this.periodCredits,
    this.startedAt,
    this.expiresAt,
    this.orderId,
    this.purchaseTokenHash,
    this.updatedAt,
  });

  final String userId;
  final String planId;
  final String? productId;
  final String status;
  final bool isActive;
  final bool autoRenews;
  final String source;
  final int periodCredits;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? orderId;
  final String? purchaseTokenHash;
  final DateTime? updatedAt;

  UserSubscription copyWith({
    String? userId,
    String? planId,
    String? productId,
    String? status,
    bool? isActive,
    bool? autoRenews,
    String? source,
    int? periodCredits,
    DateTime? startedAt,
    DateTime? expiresAt,
    String? orderId,
    String? purchaseTokenHash,
    DateTime? updatedAt,
  }) {
    return UserSubscription(
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      productId: productId ?? this.productId,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      autoRenews: autoRenews ?? this.autoRenews,
      source: source ?? this.source,
      periodCredits: periodCredits ?? this.periodCredits,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      orderId: orderId ?? this.orderId,
      purchaseTokenHash: purchaseTokenHash ?? this.purchaseTokenHash,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['user_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? 'free',
      productId: json['product_id']?.toString(),
      status: json['status']?.toString() ?? 'free',
      isActive: json['is_active'] == true,
      autoRenews: json['auto_renews'] == true,
      source: json['source']?.toString() ?? 'supabase',
      periodCredits: (json['period_credits'] as num?)?.toInt() ?? 0,
      startedAt: _parseDateTime(json['started_at']),
      expiresAt: _parseDateTime(json['expires_at']),
      orderId: json['order_id']?.toString(),
      purchaseTokenHash: json['purchase_token_hash']?.toString(),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'plan_id': planId,
      'product_id': productId,
      'status': status,
      'is_active': isActive,
      'auto_renews': autoRenews,
      'source': source,
      'period_credits': periodCredits,
      'started_at': startedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'order_id': orderId,
      'purchase_token_hash': purchaseTokenHash,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
