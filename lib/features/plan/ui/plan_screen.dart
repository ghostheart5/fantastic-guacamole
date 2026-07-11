import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
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
      final bool hasScore = ref.read(sessionScoreProvider) != null;
      _runAfterBuild(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task completed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (hasScore) {
          ref.read(appFlowProvider.notifier).toInsight();
        }
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

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final energy = ref.watch(energyProvider);
    final calendarService = ref.read(calendarServiceProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/plan_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
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
                    Text(
                      'Plan stream offline: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(tasksProvider),
                      child: const Text('Re-sync'),
                    ),
                  ],
                ),
              ),
            ),
            data: (tasks) {
              final List<TimeBlock> allBlocks = calendarService
                  .generateAdaptivePlan(tasks: tasks, energy: energy);
              final List<TimeBlock> blocks = allBlocks
                  .where((block) => (block.start.weekday - 1) == _selectedDay)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: PlanHeader(
                      onBack: () =>
                          ref.read(appFlowProvider.notifier).toCoach(),
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
                    ),
                  ),
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
