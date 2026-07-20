import 'package:flutter/material.dart';

class PremiumFeatureLockWidget extends StatelessWidget {
  const PremiumFeatureLockWidget({
    required this.featureName,
    required this.onUpgrade,
    super.key,
  });

  final String featureName;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$featureName is premium',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Upgrade to unlock this feature and premium SI tools.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onUpgrade,
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
