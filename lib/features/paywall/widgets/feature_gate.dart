import 'package:fantastic_guacamole/config/paywall_config.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/ui/system/premium_feature_gate.dart';
import 'package:flutter/material.dart';

class FeatureGate extends StatefulWidget {
  const FeatureGate({
    required this.featureName,
    required this.isUnlocked,
    required this.onOpenPaywall,
    required this.child,
    super.key,
  });

  final String featureName;
  final bool isUnlocked;
  final VoidCallback onOpenPaywall;
  final Widget child;

  @override
  State<FeatureGate> createState() => _FeatureGateState();
}

class _FeatureGateState extends State<FeatureGate> {
  bool _bypassLogged = false;

  @override
  Widget build(BuildContext context) {
    if (paywallTestingMode) {
      if (!_bypassLogged) {
        Logger.log('Paywall', 'Paywall bypassed (testing mode).');
        _bypassLogged = true;
      }
      return widget.child;
    }

    if (widget.isUnlocked) {
      return widget.child;
    }

    return PremiumFeatureGate(
      featureName: widget.featureName,
      onGoToSettings: widget.onOpenPaywall,
      subtitle: 'Open the paywall to manage access for this feature.',
    );
  }
}
