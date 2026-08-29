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
    int requiredInt(String key) {
      final Object? value = json[key];
      if (value is! num ||
          !value.isFinite ||
          value.toDouble() != value.toInt().toDouble()) {
        throw FormatException('Invalid AI credit wallet $key.');
      }
      return value.toInt();
    }

    DateTime requiredDateTime(String key) {
      final DateTime? value = DateTime.tryParse(json[key]?.toString() ?? '');
      if (value == null) {
        throw FormatException('Invalid AI credit wallet $key.');
      }
      return value.toLocal();
    }

    final int balance = requiredInt('balance');
    final int allowance = requiredInt('allowance');
    final String tier = json['tier']?.toString().trim() ?? '';
    if (!const <String>{'free', 'premium'}.contains(tier) ||
        allowance <= 0 ||
        balance < 0 ||
        balance > allowance) {
      throw const FormatException('Invalid AI credit wallet values.');
    }

    return AiCreditWallet(
      balance: balance,
      tier: tier,
      allowance: allowance,
      resetAt: requiredDateTime('resetAt'),
      updatedAt: requiredDateTime('updatedAt'),
    );
  }
}

class AiCreditSpendResult {
  const AiCreditSpendResult({required this.wallet, required this.allowed});

  final AiCreditWallet wallet;
  final bool allowed;
}
