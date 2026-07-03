import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/features/logs/widgets/logs_insight_card.dart';
import 'package:fantastic_guacamole/features/logs/widgets/logs_timeline.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final logsAsync = ref.watch(logsProvider);
    final logServices = ref.read(logServicesProvider);

    final dailyLogs = logsAsync.maybeWhen(
      data: (payload) => logServices.prepareEntries(payload.dailyLogs),
      orElse: () => <String>[],
    );
    final completedTasks = logsAsync.maybeWhen(
      data: (payload) => logServices.prepareEntries(payload.completedTasks),
      orElse: () => <String>[],
    );
    final pastMissions = logsAsync.maybeWhen(
      data: (payload) => logServices.prepareEntries(payload.pastMissions),
      orElse: () => <String>[],
    );

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/logs_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ScreenHeader(
                  title: 'CHRONOLOGS',
                  subtitle: 'SESSION HISTORY',
                  accentColor: AppColors.neonCyan,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LogsInsightCard(
                        title: 'Longest Streak',
                        value: '${profile.longestStreak}d',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LogsInsightCard(
                        title: 'XP Snapshot',
                        value: '${profile.xp}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                logsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        color: AppColors.neonCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load logs: $e',
                      style: const TextStyle(
                        color: AppColors.recallRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  data: (_) => Column(
                    children: [
                      if (dailyLogs.isNotEmpty) ...[
                        _NeonPanel(
                          label: 'DAILY LOGS',
                          accentColor: AppColors.neonCyan,
                          child: LogsTimeline(entries: dailyLogs),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (completedTasks.isNotEmpty) ...[
                        _NeonPanel(
                          label: 'COMPLETED TASKS',
                          accentColor: AppColors.memoryAmber,
                          child: _LogList(
                            entries: completedTasks,
                            icon: Icons.check_circle_outline,
                            color: AppColors.memoryAmber,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (pastMissions.isNotEmpty) ...[
                        _NeonPanel(
                          label: 'PAST MISSIONS',
                          accentColor: AppColors.neonViolet,
                          child: _LogList(
                            entries: pastMissions,
                            icon: Icons.flag_outlined,
                            color: AppColors.neonViolet,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.entries,
    required this.icon,
    required this.color,
  });

  final List<String> entries;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const _PanelDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entries[i],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [accentColor, AppColors.neonViolet],
              ).createShader(bounds),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeonPanel extends StatelessWidget {
  const _NeonPanel({
    required this.label,
    required this.child,
    required this.accentColor,
  });
  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: Colors.white10);
}
