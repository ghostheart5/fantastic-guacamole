import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _TimelineWindow { today, week, month, year, all }

enum _TimelineFocus { all, overdue, upcoming, milestones, risks, recommendations }

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _TimelineWindow _window = _TimelineWindow.week;
  _TimelineFocus _focus = _TimelineFocus.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<TimelineEventEntity> baseEvents = ref.watch(timelineProvider);
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final List<Task> tasks = ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final DateTime now = DateTime.now();

    final List<TimelineEventEntity> projected = _buildProjectedEvents(
      now: now,
      tasks: tasks,
      goals: goals,
    );
    final List<TimelineEventEntity> combined = <TimelineEventEntity>[
      ...baseEvents,
      ...projected,
      ..._buildIntelligenceEvents(
        now: now,
        events: <TimelineEventEntity>[...baseEvents, ...projected],
      ),
    ]..sort((a, b) => _eventMoment(b).compareTo(_eventMoment(a)));

    final List<TimelineEventEntity> filtered = combined
        .where((TimelineEventEntity event) {
          final DateTime moment = _eventMoment(event);
          final bool inWindow = _inWindow(moment: moment, now: now, window: _window);
          if (!inWindow) {
            return false;
          }
          final bool inFocus = switch (_focus) {
            _TimelineFocus.all => true,
            _TimelineFocus.overdue => event.isOverdue,
            _TimelineFocus.upcoming => event.isUpcoming,
            _TimelineFocus.milestones => event.isMilestone,
            _TimelineFocus.risks => event.isRisk,
            _TimelineFocus.recommendations => event.isRecommendation,
          };
          if (!inFocus) {
            return false;
          }
          final String q = _query.trim().toLowerCase();
          if (q.isEmpty) {
            return true;
          }
          return event.title.toLowerCase().contains(q) || event.detail.toLowerCase().contains(q);
        })
        .toList(growable: false);

    final Map<String, List<TimelineEventEntity>> grouped = <String, List<TimelineEventEntity>>{};
    for (final TimelineEventEntity event in filtered) {
      final String key = DateTimeFormats.timelineDay(_eventMoment(event));
      grouped.putIfAbsent(key, () => <TimelineEventEntity>[]).add(event);
    }
    final List<String> days = grouped.keys.toList(growable: false);

    final int overdueCount = filtered.where((TimelineEventEntity event) => event.isOverdue).length;
    final int upcomingCount = filtered
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;
    final int milestoneCount = filtered
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int riskCount = filtered.where((TimelineEventEntity event) => event.isRisk).length;
    final int recommendationCount = filtered
        .where((TimelineEventEntity event) => event.isRecommendation)
        .length;

    final int healthScore = _computeHealthScore(
      overdueCount: overdueCount,
      riskCount: riskCount,
      milestoneCount: milestoneCount,
      upcomingCount: upcomingCount,
    );
    final int riskScore = 100 - healthScore;
    final TimelineEventEntity? nextDeadline = _nearestUpcoming(filtered, now);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    SmartPressable(
                      onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonViolet.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonViolet,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonViolet, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'TIMELINE OPS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'EVENT CHRONOLOGY',
                          style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TutorialTarget(
                  id: 'timeline.intelligence_strip',
                  child: _TimelineIntelligenceStrip(
                    healthScore: healthScore,
                    riskScore: riskScore,
                    overdueCount: overdueCount,
                    upcomingCount: upcomingCount,
                    milestoneCount: milestoneCount,
                    riskCount: riskCount,
                    recommendationCount: recommendationCount,
                    nextDeadline: nextDeadline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search timeline...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xAA091427),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.neonViolet.withValues(alpha: 0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.neonCyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _WindowChips(
                  selected: _window,
                  onSelect: (_TimelineWindow value) => setState(() => _window = value),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _FocusChips(
                  selected: _focus,
                  onSelect: (_TimelineFocus value) => setState(() => _focus = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No timeline matches this window/filter.\nTry another view or reduce filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.6),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: days.length,
                        itemBuilder: (ctx, i) {
                          final day = days[i];
                          final dayEvents = grouped[day]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...dayEvents.map(
                                (TimelineEventEntity e) => _TimelineEventTile(event: e),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({required this.event});
  final TimelineEventEntity event;

  Color get _color {
    switch (event.type) {
      case TimelineEventType.reflection:
        return AppColors.neonViolet;
      case TimelineEventType.levelUp:
        return AppColors.memoryAmber;
      case TimelineEventType.goalComplete:
        return const Color(0xFF4CAF50);
      case TimelineEventType.streak:
        return Colors.deepOrangeAccent;
      case TimelineEventType.task:
        return AppColors.neonCyan;
      case TimelineEventType.goal:
        return const Color(0xFF7AF7C4);
      case TimelineEventType.habit:
        return const Color(0xFFFFB86B);
      case TimelineEventType.project:
        return const Color(0xFFC2A1FF);
      case TimelineEventType.milestone:
        return const Color(0xFFFFD166);
      case TimelineEventType.deadline:
        return event.isOverdue ? AppColors.recallRed : const Color(0xFF59C8FF);
      case TimelineEventType.forecast:
        return const Color(0xFF8CA0FF);
      case TimelineEventType.snapshot:
        return Colors.white70;
      case TimelineEventType.risk:
        return AppColors.recallRed;
      case TimelineEventType.recommendation:
        return AppColors.neonCyan;
    }
  }

  IconData get _icon {
    switch (event.type) {
      case TimelineEventType.reflection:
        return Icons.edit_note_rounded;
      case TimelineEventType.levelUp:
        return Icons.bolt_rounded;
      case TimelineEventType.goalComplete:
        return Icons.flag_rounded;
      case TimelineEventType.streak:
        return Icons.local_fire_department_rounded;
      case TimelineEventType.task:
        return Icons.checklist_rounded;
      case TimelineEventType.goal:
        return Icons.flag_rounded;
      case TimelineEventType.habit:
        return Icons.repeat_rounded;
      case TimelineEventType.project:
        return Icons.account_tree_rounded;
      case TimelineEventType.milestone:
        return Icons.emoji_events_rounded;
      case TimelineEventType.deadline:
        return Icons.schedule_rounded;
      case TimelineEventType.forecast:
        return Icons.insights_rounded;
      case TimelineEventType.snapshot:
        return Icons.camera_alt_outlined;
      case TimelineEventType.risk:
        return Icons.warning_amber_rounded;
      case TimelineEventType.recommendation:
        return Icons.tips_and_updates_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color.withValues(alpha: 0.4)),
                ),
                child: Icon(_icon, color: _color, size: 13),
              ),
              Container(width: 1, height: 20, color: _color.withValues(alpha: 0.15)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF050D1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _color.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          color: _color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateTimeFormats.timelineTime(_eventMoment(event)),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                  if (event.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.detail,
                      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (event.dueAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.isOverdue
                          ? 'Overdue since ${DateTimeFormats.dateShort(event.dueAt!)}'
                          : 'Due ${DateTimeFormats.dateShort(event.dueAt!)}',
                      style: TextStyle(
                        color: event.isOverdue ? AppColors.recallRed : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineIntelligenceStrip extends StatelessWidget {
  const _TimelineIntelligenceStrip({
    required this.healthScore,
    required this.riskScore,
    required this.overdueCount,
    required this.upcomingCount,
    required this.milestoneCount,
    required this.riskCount,
    required this.recommendationCount,
    required this.nextDeadline,
  });

  final int healthScore;
  final int riskScore;
  final int overdueCount;
  final int upcomingCount;
  final int milestoneCount;
  final int riskCount;
  final int recommendationCount;
  final TimelineEventEntity? nextDeadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA07111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(label: 'HEALTH', value: '$healthScore%'),
              _StatPill(label: 'RISK', value: '$riskScore%'),
              _StatPill(label: 'OVERDUE', value: '$overdueCount'),
              _StatPill(label: 'UPCOMING', value: '$upcomingCount'),
              _StatPill(label: 'MILESTONES', value: '$milestoneCount'),
              _StatPill(label: 'RISKS', value: '$riskCount'),
              _StatPill(label: 'RECS', value: '$recommendationCount'),
            ],
          ),
          if (nextDeadline != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next deadline: ${nextDeadline!.title} (${DateTimeFormats.dateShort(nextDeadline!.dueAt ?? nextDeadline!.timestamp)})',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WindowChips extends StatelessWidget {
  const _WindowChips({required this.selected, required this.onSelect});

  final _TimelineWindow selected;
  final ValueChanged<_TimelineWindow> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimelineWindow.values
            .map(
              (_TimelineWindow value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: _windowLabel(value),
                  selected: selected == value,
                  onTap: () => onSelect(value),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FocusChips extends StatelessWidget {
  const _FocusChips({required this.selected, required this.onSelect});

  final _TimelineFocus selected;
  final ValueChanged<_TimelineFocus> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimelineFocus.values
            .map(
              (_TimelineFocus value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: _focusLabel(value),
                  selected: selected == value,
                  onTap: () => onSelect(value),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonCyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.neonCyan : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

DateTime _eventMoment(TimelineEventEntity event) => event.dueAt ?? event.timestamp;

bool _inWindow({required DateTime moment, required DateTime now, required _TimelineWindow window}) {
  switch (window) {
    case _TimelineWindow.today:
      return moment.year == now.year && moment.month == now.month && moment.day == now.day;
    case _TimelineWindow.week:
      final DateTime start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final DateTime end = start.add(const Duration(days: 7));
      return !moment.isBefore(start) && moment.isBefore(end);
    case _TimelineWindow.month:
      return moment.year == now.year && moment.month == now.month;
    case _TimelineWindow.year:
      return moment.year == now.year;
    case _TimelineWindow.all:
      return true;
  }
}

String _windowLabel(_TimelineWindow value) {
  return switch (value) {
    _TimelineWindow.today => 'Today',
    _TimelineWindow.week => 'Week',
    _TimelineWindow.month => 'Month',
    _TimelineWindow.year => 'Year',
    _TimelineWindow.all => 'All',
  };
}

String _focusLabel(_TimelineFocus value) {
  return switch (value) {
    _TimelineFocus.all => 'All',
    _TimelineFocus.overdue => 'Overdue',
    _TimelineFocus.upcoming => 'Upcoming',
    _TimelineFocus.milestones => 'Milestones',
    _TimelineFocus.risks => 'Risks',
    _TimelineFocus.recommendations => 'Recommendations',
  };
}

List<TimelineEventEntity> _buildProjectedEvents({
  required DateTime now,
  required List<Task> tasks,
  required List<GoalEntity> goals,
}) {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  for (final Task task in tasks) {
    final DateTime? due = task.scheduledFor;
    if (due == null) {
      continue;
    }
    final bool overdue = due.isBefore(now);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-task-${task.id}',
        type: TimelineEventType.deadline,
        title: task.title,
        detail: overdue
            ? 'Task deadline missed. Re-plan this task immediately.'
            : 'Task is scheduled and approaching deadline.',
        timestamp: now,
        status: overdue ? TimelineEventStatus.overdue : TimelineEventStatus.planned,
        dueAt: due,
        phase: 'task',
        relatedId: task.id,
      ),
    );
  }

  for (final GoalEntity goal in goals) {
    final DateTime? target = goal.targetDate;
    if (target == null) {
      continue;
    }
    final bool overdue = target.isBefore(now);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-goal-${goal.id}',
        type: TimelineEventType.goal,
        title: goal.title,
        detail: overdue
            ? 'Goal target date has passed. Recovery plan needed.'
            : 'Goal target date is upcoming.',
        timestamp: now,
        status: overdue ? TimelineEventStatus.overdue : TimelineEventStatus.active,
        dueAt: target,
        phase: 'goal',
        relatedId: goal.id,
      ),
    );
  }

  return events;
}

List<TimelineEventEntity> _buildIntelligenceEvents({
  required DateTime now,
  required List<TimelineEventEntity> events,
}) {
  final int overdue = events.where((TimelineEventEntity event) => event.isOverdue).length;
  final int upcoming = events.where((TimelineEventEntity event) => event.isUpcoming).length;
  final int risk = overdue > 0 ? 1 : 0;
  final List<TimelineEventEntity> out = <TimelineEventEntity>[
    TimelineEventEntity(
      id: 'timeline-snapshot-${now.millisecondsSinceEpoch}',
      type: TimelineEventType.snapshot,
      title: 'Timeline Snapshot',
      detail: 'Overdue: $overdue · Upcoming: $upcoming · Total events: ${events.length}',
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'snapshot',
    ),
  ];
  if (risk > 0) {
    out.add(
      TimelineEventEntity(
        id: 'timeline-risk-${now.millisecondsSinceEpoch}',
        type: TimelineEventType.risk,
        title: 'Timeline Risk Detected',
        detail: 'You have $overdue overdue items. Prioritize overdue resolution first.',
        timestamp: now,
        status: TimelineEventStatus.atRisk,
        phase: 'risk',
      ),
    );
    out.add(
      TimelineEventEntity(
        id: 'timeline-rec-${now.millisecondsSinceEpoch}',
        type: TimelineEventType.recommendation,
        title: 'Recommended Action',
        detail: 'Complete overdue tasks before adding new commitments.',
        timestamp: now,
        status: TimelineEventStatus.info,
        phase: 'recommendation',
      ),
    );
  }
  return out;
}

int _computeHealthScore({
  required int overdueCount,
  required int riskCount,
  required int milestoneCount,
  required int upcomingCount,
}) {
  final int penalty = (overdueCount * 12) + (riskCount * 10) + (upcomingCount > 6 ? 8 : 0);
  final int bonus = (milestoneCount * 3).clamp(0, 18);
  return (100 - penalty + bonus).clamp(0, 100);
}

TimelineEventEntity? _nearestUpcoming(List<TimelineEventEntity> events, DateTime now) {
  final List<TimelineEventEntity> candidates =
      events
          .where((TimelineEventEntity event) {
            final DateTime? due = event.dueAt;
            return due != null && due.isAfter(now) && !event.isOverdue;
          })
          .toList(growable: false)
        ..sort((a, b) => (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp));
  return candidates.isEmpty ? null : candidates.first;
}
