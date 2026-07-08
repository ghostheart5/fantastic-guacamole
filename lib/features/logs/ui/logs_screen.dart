import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/features/logs/widgets/logs_insight_card.dart';
import 'package:fantastic_guacamole/features/logs/widgets/logs_timeline.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final logsAsync = ref.watch(logsProvider);
    final _LogBuckets buckets = _partitionLogMessages(logsAsync.entries);
    final List<String> dailyLogs = buckets.dailyLogs;
    final List<String> completedTasks = buckets.completedTasks;
    final List<String> pastMissions = buckets.pastMissions;

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
                  title: 'ACTIVITY LEDGER',
                  subtitle: 'EXECUTION RECORD',
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
                if (logsAsync.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        color: AppColors.neonCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (logsAsync.error != null)
                  Center(
                    child: Text(
                      'Log stream offline: ${logsAsync.error}',
                      style: const TextStyle(
                        color: AppColors.recallRed,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      if (dailyLogs.isNotEmpty) ...[
                        _NeonPanel(
                          label: 'DAILY SIGNALS',
                          accentColor: AppColors.neonCyan,
                          child: LogsTimeline(entries: dailyLogs),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (completedTasks.isNotEmpty) ...[
                        _NeonPanel(
                          label: 'COMPLETED ACTIONS',
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
                          label: 'MISSION HISTORY',
                          accentColor: AppColors.neonViolet,
                          child: _LogList(
                            entries: pastMissions,
                            icon: Icons.flag_outlined,
                            color: AppColors.neonViolet,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (dailyLogs.isEmpty &&
                          completedTasks.isEmpty &&
                          pastMissions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Your completed actions and mission events will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
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
    return ListView.separated(
      itemCount: entries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const _PanelDivider(),
      itemBuilder: (BuildContext context, int i) {
        return Padding(
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
        );
      },
    );
  }
}

_LogBuckets _partitionLogMessages(List<LogEntryEntity> entries) {
  final List<String> dailyLogs = <String>[];
  final List<String> completedTasks = <String>[];
  final List<String> pastMissions = <String>[];

  for (final LogEntryEntity entry in entries) {
    switch (entry.source) {
      case 'focus_session':
      case 'daily_log':
        dailyLogs.add(entry.message);
        break;
      case 'completed_task':
        completedTasks.add(entry.message);
        break;
      case 'mission':
        pastMissions.add(entry.message);
        break;
      default:
        break;
    }
  }

  return _LogBuckets(
    dailyLogs: List<String>.unmodifiable(dailyLogs),
    completedTasks: List<String>.unmodifiable(completedTasks),
    pastMissions: List<String>.unmodifiable(pastMissions),
  );
}

class _LogBuckets {
  const _LogBuckets({
    required this.dailyLogs,
    required this.completedTasks,
    required this.pastMissions,
  });

  final List<String> dailyLogs;
  final List<String> completedTasks;
  final List<String> pastMissions;
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
