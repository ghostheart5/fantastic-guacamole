class AiCreditTransaction {
  const AiCreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.source,
    required this.description,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String source;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  bool get isDebit => amount < 0;

  factory AiCreditTransaction.fromMap(Map<String, dynamic> map) {
    return AiCreditTransaction(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'unknown',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (map['balance_after'] as num?)?.toInt() ?? 0,
      source: map['source']?.toString() ?? 'unknown',
      description: map['description']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata:
          (map['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}