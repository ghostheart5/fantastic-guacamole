import 'package:fantastic_guacamole/features/monetization/data/models/ai_credit_wallet.dart';
import 'package:flutter/material.dart';

class CreditBalanceWidget extends StatelessWidget {
  const CreditBalanceWidget({required this.wallet, super.key});

  final AiCreditWallet? wallet;

  @override
  Widget build(BuildContext context) {
    final AiCreditWallet? current = wallet;
    if (current == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No wallet available for this user yet.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Credit Wallet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Balance: ${current.balance}'),
            Text('Allowance remaining: ${current.allowanceRemaining}'),
            Text('Bonus balance: ${current.bonusBalance}'),
            Text('Tier: ${current.tier}'),
          ],
        ),
      ),
    );
  }
}
