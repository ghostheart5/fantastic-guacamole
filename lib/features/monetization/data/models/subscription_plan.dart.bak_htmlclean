class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.productId,
    required this.planType,
    required this.priceMicros,
    required this.currencyCode,
    required this.billingPeriod,
    required this.creditsPerPeriod,
    required this.isActive,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String productId;
  final String planType;
  final int priceMicros;
  final String currencyCode;
  final String billingPeriod;
  final int creditsPerPeriod;
  final bool isActive;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? productId,
    String? planType,
    int? priceMicros,
    String? currencyCode,
    String? billingPeriod,
    int? creditsPerPeriod,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      planType: planType ?? this.planType,
      priceMicros: priceMicros ?? this.priceMicros,
      currencyCode: currencyCode ?? this.currencyCode,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      creditsPerPeriod: creditsPerPeriod ?? this.creditsPerPeriod,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      planType: json['plan_type']?.toString() ?? 'subscription',
      priceMicros: (json['price_micros'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code']?.toString() ?? 'USD',
      billingPeriod: json['billing_period']?.toString() ?? 'monthly',
      creditsPerPeriod: (json['credits_per_period'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      description: json['description']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'product_id': productId,
      'plan_type': planType,
      'price_micros': priceMicros,
      'currency_code': currencyCode,
      'billing_period': billingPeriod,
      'credits_per_period': creditsPerPeriod,
      'is_active': isActive,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
