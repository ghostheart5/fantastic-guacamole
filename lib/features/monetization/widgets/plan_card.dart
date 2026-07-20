import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.currentStatus,
    required this.onPressed,
    this.busy = false,
  });

  final SubscriptionPlan plan;
  final SubscriptionStatus currentStatus;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bool active = currentStatus.planId == plan.id && currentStatus.isActive;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: active
              ? <Color>[
                  AppColors.neonCyan.withValues(alpha: 0.22),
                  AppColors.neonViolet.withValues(alpha: 0.20),
                ]
              : <Color>[Colors.white10, Colors.white12],
        ),
        border: Border.all(
          color: plan.isFeatured
              ? AppColors.neonCyan.withValues(alpha: 0.55)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (plan.isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.neonViolet.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(plan.subtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(
            plan.priceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(plan.billingLabel, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          ...plan.featureIds.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.neonCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: active || busy || !plan.isAvailable ? null : onPressed,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(active ? 'Active' : plan.isLifetime ? 'Unlock Lifetime' : 'Subscribe'),
          ),
        ],
      ),
    );
  }
}