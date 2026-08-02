class AiCreditWallet {
  const AiCreditWallet({
    required this.userId,
    required this.balance,
    required this.allowanceRemaining,
    required this.bonusBalance,
    required this.periodCredits,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.tier,
    this.periodEndsAt,
    this.updatedAt,
  });

  final String userId;
  final int balance;
  final int allowanceRemaining;
  final int bonusBalance;
  final int periodCredits;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final String tier;
  final DateTime? periodEndsAt;
  final DateTime? updatedAt;

  AiCreditWallet copyWith({
    String? userId,
    int? balance,
    int? allowanceRemaining,
    int? bonusBalance,
    int? periodCredits,
    int? lifetimeEarned,
    int? lifetimeSpent,
    String? tier,
    DateTime? periodEndsAt,
    DateTime? updatedAt,
  }) {
    return AiCreditWallet(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      allowanceRemaining: allowanceRemaining ?? this.allowanceRemaining,
      bonusBalance: bonusBalance ?? this.bonusBalance,
      periodCredits: periodCredits ?? this.periodCredits,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      tier: tier ?? this.tier,
      periodEndsAt: periodEndsAt ?? this.periodEndsAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AiCreditWallet.fromJson(Map<String, dynamic> json) {
    return AiCreditWallet(
      userId: json['user_id']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      allowanceRemaining: (json['allowance_remaining'] as num?)?.toInt() ?? 0,
      bonusBalance: (json['bonus_balance'] as num?)?.toInt() ?? 0,
      periodCredits: (json['period_credits'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (json['lifetime_spent'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'free',
      periodEndsAt: _parseDateTime(json['period_ends_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'balance': balance,
      'allowance_remaining': allowanceRemaining,
      'bonus_balance': bonusBalance,
      'period_credits': periodCredits,
      'lifetime_earned': lifetimeEarned,
      'lifetime_spent': lifetimeSpent,
      'tier': tier,
      'period_ends_at': periodEndsAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
