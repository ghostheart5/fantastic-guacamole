import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DecisionIntelligenceCard extends StatelessWidget {
  const DecisionIntelligenceCard({
    required this.intelligence,
    required this.onAction,
    this.onAcknowledge,
    this.title = 'Planning summary',
    this.compact = false,
    this.topRisk,
    this.recentProgress,
    super.key,
  });

  final DecisionIntelligence intelligence;
  final VoidCallback onAction;
  final VoidCallback? onAcknowledge;
  final String title;
  final bool compact;
  final String? topRisk;
  final String? recentProgress;

  @override
  Widget build(BuildContext context) {
    final OperatingSnapshot snapshot = intelligence.snapshot;
    final OperatingDecisionReceipt decision = intelligence.decision;
    final List<OperatingChange> changes = intelligence.delta.materialChanges;
    return Semantics(
      container: true,
      liveRegion: intelligence.hasUnacknowledgedChange,
      label: '$title. ${intelligence.delta.summary}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: const Color(0xEE06101D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: .28)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: .05),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Badge(label: decision.confidence.name),
              ],
            ),
            const SizedBox(height: 12),
            _Answer(
              label: 'WHERE YOU ARE',
              value:
                  '${snapshot.actionableCount} actionable, ${snapshot.overdueCount} overdue, ${snapshot.completedToday} completed today. Momentum ${snapshot.momentum}%, pressure ${snapshot.pressure}%.',
            ),
            _Answer(
              label: 'WHAT CHANGED',
              value:
                  recentProgress ??
                  (changes.isEmpty
                      ? intelligence.delta.summary
                      : changes
                            .take(3)
                            .map(
                              (OperatingChange item) =>
                                  '${item.label}: ${item.previousValue} to ${item.currentValue}',
                            )
                            .join('. ')),
            ),
            _Answer(
              label: 'WHAT MATTERS NEXT',
              value: decision.recommendedAction,
              emphasized: true,
            ),
            _Answer(
              label: 'WHY THIS MATTERS',
              value: '${decision.rationale} ${decision.whyItMatters}',
            ),
            if (topRisk != null) _Answer(label: 'TOP RISK', value: topRisk!),
            if (!compact) ...<Widget>[
              _Answer(label: 'IF DELAYED', value: decision.consequenceOfDelay),
              Text(
                'Evidence ${(snapshot.evidenceCoverage * 100).round()}% ready • ${decision.isExpired ? 'refresh required' : 'current'} • ${decision.modelVersion}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: decision.isExpired ? null : onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(decision.actionIntent.label),
                ),
                if (intelligence.hasUnacknowledgedChange &&
                    onAcknowledge != null)
                  TextButton(
                    onPressed: onAcknowledge,
                    child: const Text('Mark update reviewed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? Colors.white : Colors.white70,
              fontSize: emphasized ? 15 : 12,
              height: 1.4,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (Match match) => ' ${match.group(1)}',
            )
            .trim(),
        style: const TextStyle(
          color: AppColors.neonCyan,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
