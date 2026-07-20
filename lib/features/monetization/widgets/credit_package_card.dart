import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreditPackageCard extends StatelessWidget {
  const CreditPackageCard({
    super.key,
    required this.package,
    required this.onPressed,
    this.busy = false,
  });

  final AiCreditPackage package;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(
          color: package.isFeatured
              ? AppColors.neonViolet.withValues(alpha: 0.55)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            package.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${package.totalCredits} total credits',
            style: const TextStyle(color: Colors.white70),
          ),
          if (package.bonusCredits > 0)
            Text(
              '${package.bonusCredits} bonus included',
              style: const TextStyle(color: AppColors.neonCyan),
            ),
          const SizedBox(height: 8),
          Text(
            package.description,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                package.priceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: busy || !package.isAvailable ? null : onPressed,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}