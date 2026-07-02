class AiCreditWallet {
  const AiCreditWallet({
    required this.balance,
    required this.tier,
    required this.allowance,
    required this.resetAt,
    required this.updatedAt,
  });

  final int balance;
  final String tier;
  final int allowance;
  final DateTime resetAt;
  final DateTime updatedAt;

  bool get isExhausted => balance <= 0;

  bool get isLow => balance <= (allowance / 4).ceil();

  AiCreditWallet copyWith({
    int? balance,
    String? tier,
    int? allowance,
    DateTime? resetAt,
    DateTime? updatedAt,
  }) {
    return AiCreditWallet(
      balance: balance ?? this.balance,
      tier: tier ?? this.tier,
      allowance: allowance ?? this.allowance,
      resetAt: resetAt ?? this.resetAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'balance': balance,
      'tier': tier,
      'allowance': allowance,
      'resetAt': resetAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory AiCreditWallet.fromJson(Map<String, dynamic> json) {
    return AiCreditWallet(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'free',
      allowance: (json['allowance'] as num?)?.toInt() ?? 10,
      resetAt:
          DateTime.tryParse(json['resetAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(days: 1)),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class AiCreditSpendResult {
  const AiCreditSpendResult({required this.wallet, required this.allowed});

  final AiCreditWallet wallet;
  final bool allowed;
}
