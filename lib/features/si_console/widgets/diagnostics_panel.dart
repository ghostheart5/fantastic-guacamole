import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum _DiagnosticSeverity { critical, warning, info }

class _DiagnosticMeta {
  final _DiagnosticSeverity severity;
  final IconData icon;
  final Color color;

  const _DiagnosticMeta({
    required this.severity,
    required this.icon,
    required this.color,
  });
}

class DiagnosticsPanel extends StatelessWidget {
  final String summary;
  final List<String> diagnostics;

  const DiagnosticsPanel({
    super.key,
    required this.summary,
    required this.diagnostics,
  });

  _DiagnosticMeta _metaFor(String text) {
    final String lowered = text.toLowerCase();
    if (lowered.startsWith('critical:')) {
      return const _DiagnosticMeta(
        severity: _DiagnosticSeverity.critical,
        icon: Icons.error_outline,
        color: AppColors.recallRed,
      );
    }
    if (lowered.startsWith('warning:')) {
      return const _DiagnosticMeta(
        severity: _DiagnosticSeverity.warning,
        icon: Icons.warning_amber_rounded,
        color: AppColors.memoryAmber,
      );
    }
    return const _DiagnosticMeta(
      severity: _DiagnosticSeverity.info,
      icon: Icons.monitor_heart_outlined,
      color: AppColors.pulseNeonBlue,
    );
  }

  String _label(_DiagnosticSeverity severity) {
    switch (severity) {
      case _DiagnosticSeverity.critical:
        return 'CRITICAL';
      case _DiagnosticSeverity.warning:
        return 'WARNING';
      case _DiagnosticSeverity.info:
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
        ...diagnostics.map((String entry) {
          final _DiagnosticMeta meta = _metaFor(entry);
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
                      Text(entry),
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
