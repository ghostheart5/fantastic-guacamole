import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AiCreditBalanceCard extends StatelessWidget {
  const AiCreditBalanceCard({super.key, required this.wallet});

  final AiCreditWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI CREDIT WALLET',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${wallet.balance}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Allowance ${wallet.allowanceRemaining}  •  Bonus ${wallet.bonusBalance}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (wallet.periodEndsAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Current cycle ends ${wallet.periodEndsAt!.toLocal()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}