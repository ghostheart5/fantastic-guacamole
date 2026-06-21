import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum _InsightSeverity { critical, warning, info }

class _InsightMeta {
  final _InsightSeverity severity;
  final IconData icon;
  final Color color;

  const _InsightMeta({
    required this.severity,
    required this.icon,
    required this.color,
  });
}

class InsightsPanel extends StatelessWidget {
  final String summary;
  final List<String> insights;
  const InsightsPanel({
    super.key,
    required this.summary,
    required this.insights,
  });

  _InsightMeta _metaFor(String text) {
    final String lowered = text.toLowerCase();
    if (lowered.startsWith('critical:')) {
      return const _InsightMeta(
        severity: _InsightSeverity.critical,
        icon: Icons.error_outline,
        color: AppColors.recallRed,
      );
    }
    if (lowered.startsWith('warning:')) {
      return const _InsightMeta(
        severity: _InsightSeverity.warning,
        icon: Icons.warning_amber_rounded,
        color: AppColors.memoryAmber,
      );
    }
    return const _InsightMeta(
      severity: _InsightSeverity.info,
      icon: Icons.info_outline,
      color: AppColors.pulseNeonBlue,
    );
  }

  String _label(_InsightSeverity severity) {
    switch (severity) {
      case _InsightSeverity.critical:
        return 'CRITICAL';
      case _InsightSeverity.warning:
        return 'WARNING';
      case _InsightSeverity.info:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...insights.map((String insight) {
          final _InsightMeta meta = _metaFor(insight);
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: meta.color.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(meta.icon, color: meta.color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _label(meta.severity),
                        style: TextStyle(
                          color: meta.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(insight),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
