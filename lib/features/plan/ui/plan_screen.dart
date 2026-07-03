import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/data/models/time_block.dart';
import 'package:fantastic_guacamole/features/plan/widgets/day_overview_card.dart';
import 'package:fantastic_guacamole/features/plan/widgets/day_selector.dart';
import 'package:fantastic_guacamole/features/plan/widgets/plan_header.dart';
import 'package:fantastic_guacamole/features/plan/widgets/timeline.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int _selectedDay = DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final energy = ref.watch(energyProvider);
    final calendarService = ref.read(calendarServiceProvider);

    final List<TimeBlock> allBlocks = tasksAsync.when(
      data: (tasks) =>
          calendarService.generateAdaptivePlan(tasks: tasks, energy: energy),
      loading: () => <TimeBlock>[],
      error: (e, st) => <TimeBlock>[],
    );

    final List<TimeBlock> blocks = allBlocks
        .where((block) => (block.start.weekday - 1) == _selectedDay)
        .toList(growable: false);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/plan_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: PlanHeader(
                  onBack: () => ref.read(appFlowProvider.notifier).toCoach(),
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
                        child: Timeline(blocks: blocks),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
