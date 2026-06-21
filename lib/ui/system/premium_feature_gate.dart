import 'package:flutter/material.dart';

import '../../core/system/subscription_model.dart';
import 'glass_panel.dart';

class PremiumFeatureGate extends StatelessWidget {
  const PremiumFeatureGate({
    required this.featureName,
    required this.onGoToSettings,
    this.subtitle,
    this.currentPlan,
    super.key,
  });

  final String featureName;
  final VoidCallback onGoToSettings;
  final String? subtitle;
  final SubscriptionPlan? currentPlan;

  @override
  Widget build(BuildContext context) {
    final String displaySubtitle = subtitle ?? _getDefaultSubtitle();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.workspace_premium, color: Color(0xFFC2A7FF), size: 32),
              const SizedBox(height: 12),
              Text(
                '$featureName requires Premium access.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                displaySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD8D0E6)),
              ),
              if (currentPlan == SubscriptionPlan.base) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA500).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFFFA500)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Free Trial Limit Reached',
                        style: TextStyle(
                          color: Color(0xFFFFA500),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upgrade to Premium for unlimited access.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: const Color(0xFFFFA500)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onGoToSettings,
                icon: const Icon(Icons.lock_open),
                label: const Text('Upgrade to Premium'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDefaultSubtitle() {
    if (currentPlan == SubscriptionPlan.base) {
      return 'You\'ve used your free trial opens. Upgrade to Premium for unlimited access.';
    }
    return 'Unlock this module from Settings > Billing & Access.';
  }
}
