import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/ui/system/glass_panel.dart';
import 'package:flutter/material.dart';

class PremiumFeatureGate extends StatelessWidget {
  const PremiumFeatureGate({
    required this.featureName,
    required this.onGoToSettings,
    this.subtitle,
    super.key,
  });

  final String featureName;
  final VoidCallback onGoToSettings;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (paywallTestingMode) {
      Logger.log('Paywall', 'Paywall bypassed (testing mode).');
      return const SizedBox.shrink();
    }

    final String displaySubtitle = subtitle ?? _getDefaultSubtitle();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFFC2A7FF),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                '$featureName requires Premium access.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                displaySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD8D0E6)),
              ),
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
    return 'Unlock this module from Settings > Billing & Access.';
  }
}
