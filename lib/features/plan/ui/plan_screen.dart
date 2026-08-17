import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/usecases/analyze_plan_context.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_adaptive_plan.dart';
import 'package:fantastic_guacamole/features/plan/widgets/day_overview_card.dart';
import 'package:fantastic_guacamole/features/plan/widgets/day_selector.dart';
import 'package:fantastic_guacamole/features/plan/widgets/plan_header.dart';
import 'package:fantastic_guacamole/features/plan/widgets/timeline.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int _selectedDay = DateTime.now().weekday - 1;
  final Set<String> _completingTaskIds = <String>{};

  /// The actual calendar date the selected day-of-week chip refers to, within
  /// the current Mon-Sun week. [DaySelector] only carries a weekday index, so
  /// blocks must be matched against this real date rather than weekday alone
  /// — otherwise a task scheduled on the same weekday in a past or future
  /// week would render as if it belonged to the current week.
  DateTime get _selectedDate {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: _selectedDay));
  }

  void _runAfterBuild(VoidCallback action) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      action();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  Future<void> _completePlannedTask(String taskId) async {
    if (_completingTaskIds.contains(taskId)) return;
    if (mounted) {
      setState(() => _completingTaskIds.add(taskId));
    } else {
      _completingTaskIds.add(taskId);
    }
    try {
      await ref.read(taskActionsProvider).completeTask(taskId, notify: false);
      if (!mounted) {
        return;
      }
      _runAfterBuild(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task completed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (error) {
      Logger.error('Plan task completion failed.', error);
      if (!mounted) {
        return;
      }
      _runAfterBuild(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete that task. Please retry.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(tasksProvider);
      });
    } finally {
      if (mounted) {
        setState(() => _completingTaskIds.remove(taskId));
      } else {
        _completingTaskIds.remove(taskId);
      }
    }
  }

  // Memo for the generated day plan. build() runs on every task-completion
  // setState, every day-chip tap and every energy tick, and each run
  // regenerated the whole plan — producing structurally identical blocks with
  // new millisecond-derived ids, which also defeated downstream diffing.
  List<TimeBlock>? _cachedPlan;
  Object? _cachedPlanKey;

  /// Returns the adaptive plan, regenerating only when its inputs change.
  ///
  /// The key covers task identity/ordering and the energy bucket. Energy is
  /// bucketed to two decimals because the raw value drifts continuously and
  /// sub-percent changes do not alter the ranking meaningfully.
  List<TimeBlock> _adaptivePlanFor({
    required GenerateAdaptivePlan generateAdaptivePlan,
    required List<Task> tasks,
    required double energy,
  }) {
    final String key = <String>[
      energy.toStringAsFixed(2),
      for (final Task task in tasks)
        '${task.id}:${task.priority}:${task.difficulty}:${task.energyRequired}:'
            '${task.scheduledFor?.toIso8601String() ?? ''}:'
            '${task.recurrenceRule.name}',
    ].join('|');

    final List<TimeBlock>? cached = _cachedPlan;
    if (cached != null && _cachedPlanKey == key) {
      return cached;
    }
    final List<TimeBlock> generated = generateAdaptivePlan(
      tasks: tasks,
      energy: energy,
    );
    _cachedPlan = generated;
    _cachedPlanKey = key;
    return generated;
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final energy = ref.watch(energyProvider);
    final generateAdaptivePlan = ref.read(generateAdaptivePlanUseCaseProvider);
    final analyzePlanContext = ref.read(analyzePlanContextUseCaseProvider);
    final recommendNextBlock = ref.read(recommendNextBlockUseCaseProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/plan_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.recallRed,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      // Never surface the raw error object here: it leaks
                      // stack detail to users and reads as a crash.
                      "We couldn't load your plan right now.\n"
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(tasksProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (tasks) {
              final List<TimeBlock> allBlocks = _adaptivePlanFor(
                generateAdaptivePlan: generateAdaptivePlan,
                tasks: tasks,
                energy: energy,
              );
              final List<TimeBlock> blocks = allBlocks
                  .where((block) {
                    final DateTime selected = _selectedDate;
                    return block.start.year == selected.year &&
                        block.start.month == selected.month &&
                        block.start.day == selected.day;
                  })
                  .toList(growable: false);

              // Load/capacity for the selected day, and unplanned work across
              // the whole plan (a task scheduled on another day is not
              // "unplanned" just because it is absent from today).
              final PlanContext dayContext = analyzePlanContext(
                blocks: blocks,
                tasks: tasks,
                energy: energy,
              );
              final PlanContext planContext = analyzePlanContext(
                blocks: allBlocks,
                tasks: tasks,
                energy: energy,
              );
              final TimeBlock? nextBlock = recommendNextBlock(blocks: blocks);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: PlanHeader(
                      onBack: () =>
                          ref.read(appFlowProvider.notifier).toNexus(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: DaySelector(
                      selectedIndex: _selectedDay,
                      onSelect: (day) => setState(() => _selectedDay = day),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: DayOverviewCard(
                      blocksCount: blocks.length,
                      energy: energy,
                      plannedMinutes: dayContext.plannedMinutes,
                      unplannedTaskCount: planContext.unplannedTaskCount,
                    ),
                  ),
                  if (dayContext.isOverloaded) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _OverloadedDayBanner(
                        plannedMinutes: dayContext.plannedMinutes,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Expanded(
                    child: blocks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.neonViolet.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.neonViolet.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: AppColors.neonViolet,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'NO PLAN YET',
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 2,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add tasks to generate your daily schedule',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white24,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Timeline(
                              blocks: blocks,
                              onCompleteTask: _completePlannedTask,
                              completingTaskIds: _completingTaskIds,
                              highlightedBlockId: nextBlock?.id,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shown when [AnalyzePlanContext] reports the selected day exceeds its
/// planned-minutes threshold, so an overloaded day is visible before the user
/// works through it.
class _OverloadedDayBanner extends StatelessWidget {
  const _OverloadedDayBanner({required this.plannedMinutes});

  final int plannedMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.memoryAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.memoryAmber,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Heavy day: ${DayOverviewCard.formatMinutes(plannedMinutes)} '
              'scheduled. Consider moving lower-priority work.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
