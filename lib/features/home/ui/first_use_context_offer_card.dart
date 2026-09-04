import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// One optional, post-value invitation to save a narrow piece of context.
/// This widget never gathers personality, life-history, or inferred emotion.
class FirstUseContextOfferCard extends StatelessWidget {
  const FirstUseContextOfferCard({
    super.key,
    required this.immediateGoal,
    required this.onAdd,
    required this.onDismiss,
  });

  final String immediateGoal;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('first-use-context-offer'),
      container: true,
      label:
          'Optional current-priority context. Use only this time remains the default.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: .42),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'OPTIONAL CONTEXT FOR THIS GOAL',
              style: TextStyle(
                color: AppColors.neonViolet,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              immediateGoal.trim().isEmpty
                  ? 'Would saving your exact current priority help later Smart Planner decisions?'
                  : 'After this plan for “${immediateGoal.trim()}”, would saving your exact current priority help later Smart Planner decisions?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nothing is inferred. Use only this time remains the default. If you opt in, you choose the exact words.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'Before saving: purpose · decision support  |  scope · Smart Planner only  |  expiry · 30 days  |  effect · may break a close ranking tie while this priority is active',
              style: TextStyle(
                color: Color(0xFFB9C5DD),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('first-use-context-add'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add optional context'),
                ),
                TextButton(
                  key: const Key('first-use-context-dismiss'),
                  onPressed: onDismiss,
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
