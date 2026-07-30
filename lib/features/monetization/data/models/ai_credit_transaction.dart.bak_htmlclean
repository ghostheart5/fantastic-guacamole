class AiCreditTransaction {
  const AiCreditTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.source,
    required this.description,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final int amount;
  final int balanceAfter;
  final String source;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  AiCreditTransaction copyWith({
    String? id,
    String? userId,
    String? type,
    int? amount,
    int? balanceAfter,
    String? source,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return AiCreditTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      source: source ?? this.source,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AiCreditTransaction.fromJson(Map<String, dynamic> json) {
    return AiCreditTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? 'unknown',
      description: json['description']?.toString() ?? '',
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'balance_after': balanceAfter,
      'source': source,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
