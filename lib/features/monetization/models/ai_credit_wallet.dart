class AiCreditWallet {
  const AiCreditWallet({
    required this.balance,
    required this.allowanceRemaining,
    required this.bonusBalance,
    required this.periodCredits,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.tier,
    required this.updatedAt,
    this.periodEndsAt,
  });

  final int balance;
  final int allowanceRemaining;
  final int bonusBalance;
  final int periodCredits;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final String tier;
  final DateTime updatedAt;
  final DateTime? periodEndsAt;

  bool get isExhausted => balance <= 0;
  bool get isLow => balance <= 25;

  static AiCreditWallet free() {
    return AiCreditWallet(
      balance: 20,
      allowanceRemaining: 20,
      bonusBalance: 0,
      periodCredits: 20,
      lifetimeEarned: 20,
      lifetimeSpent: 0,
      tier: 'free',
      updatedAt: DateTime.now(),
      periodEndsAt: DateTime.now().add(const Duration(days: 1)),
    );
  }

  factory AiCreditWallet.fromMap(Map<String, dynamic> map) {
    return AiCreditWallet(
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      allowanceRemaining: (map['allowance_remaining'] as num?)?.toInt() ?? 0,
      bonusBalance: (map['bonus_balance'] as num?)?.toInt() ?? 0,
      periodCredits: (map['period_credits'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (map['lifetime_earned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (map['lifetime_spent'] as num?)?.toInt() ?? 0,
      tier: map['tier']?.toString() ?? 'free',
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      periodEndsAt: DateTime.tryParse(map['period_ends_at']?.toString() ?? ''),
    );
  }
}