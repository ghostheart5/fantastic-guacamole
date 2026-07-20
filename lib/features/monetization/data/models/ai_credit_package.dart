class AiCreditPackage {
  const AiCreditPackage({
    required this.id,
    required this.productId,
    required this.name,
    required this.credits,
    required this.bonusCredits,
    required this.priceMicros,
    required this.currencyCode,
    required this.isActive,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String productId;
  final String name;
  final int credits;
  final int bonusCredits;
  final int priceMicros;
  final String currencyCode;
  final bool isActive;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get totalCredits => credits + bonusCredits;

  AiCreditPackage copyWith({
    String? id,
    String? productId,
    String? name,
    int? credits,
    int? bonusCredits,
    int? priceMicros,
    String? currencyCode,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiCreditPackage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      bonusCredits: bonusCredits ?? this.bonusCredits,
      priceMicros: priceMicros ?? this.priceMicros,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AiCreditPackage.fromJson(Map<String, dynamic> json) {
    return AiCreditPackage(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      bonusCredits: (json['bonus_credits'] as num?)?.toInt() ?? 0,
      priceMicros: (json['price_micros'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code']?.toString() ?? 'USD',
      isActive: json['is_active'] == true,
      description: json['description']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'product_id': productId,
      'name': name,
      'credits': credits,
      'bonus_credits': bonusCredits,
      'price_micros': priceMicros,
      'currency_code': currencyCode,
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
