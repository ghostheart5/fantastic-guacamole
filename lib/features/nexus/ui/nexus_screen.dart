import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/app/router/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/features/plan/widgets/time_block_widget.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/nexus_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

part 'nexus_screen.widgets.dart';

class NexusScreen extends ConsumerStatefulWidget {
  const NexusScreen({super.key});

  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final Set<String> _completingTaskIds = <String>{};
  String? _shownDecisionId;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MediaQueryData media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _pulse
        ..stop()
        ..value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState profile = ref.watch(profileProvider);
    final siState = ref.watch(siStateProvider);
    final double energy = siState.energy;
    final double fatigue = siState.fatigue;
    final NexusDecisionModel decisionModel = ref.watch(nexusDecisionProvider);
    _recordDecisionShown(decisionModel.intelligence?.decision);
    final AsyncValue<List<TimeBlock>> todayBlocks = ref.watch(
      todayTimeBlocksProvider,
    );
    final TimeBlock? nextBlock = ref.watch(nextTodayTimeBlockProvider);
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTimelineThreads,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _NexusHeader(profile: profile)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _NexusTimeBlockSchedule(
                    blocks: todayBlocks,
                    nextBlockId: nextBlock?.id,
                    decisionModel: decisionModel,
                    completingTaskIds: _completingTaskIds,
                    onCompleteTask: _completeTimeBlockTask,
                    onRetry: () => ref.invalidate(tasksProvider),
                    onCreateTask: () =>
                        goToAppView(context, ref, AppView.creator),
                    onOpenTimeline: () =>
                        goToAppView(context, ref, AppView.timeline),
                    onReviewPlan: _reviewNextDecision,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _SystemRings(
                      energy: energy,
                      fatigue: fatigue,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _RingLabels(energy: energy, fatigue: fatigue),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeTimeBlockTask(String taskId) async {
    if (_completingTaskIds.contains(taskId)) {
      return;
    }
    final OperatingDecisionReceipt? activeDecision = ref
        .read(nexusDecisionProvider)
        .intelligence
        ?.decision;
    setState(() => _completingTaskIds.add(taskId));
    try {
      await ref.read(taskActionsProvider).completeTask(taskId, notify: false);
      if (activeDecision?.subjectId == taskId) {
        await ref
            .read(decisionOutcomeActionsProvider)
            .record(
              receipt: activeDecision!,
              kind: DecisionOutcomeKind.completed,
              surface: 'nexus',
            );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ChronoSparkLocalizations.of(
              context,
            ).text(ChronoSparkString.timeBlockCompleted),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'NexusTimeBlocks',
        'Time-block completion failed.',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ChronoSparkLocalizations.of(
              context,
            ).text(ChronoSparkString.timeBlockCompletionFailed),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(tasksProvider);
    } finally {
      if (mounted) {
        setState(() => _completingTaskIds.remove(taskId));
      }
    }
  }

  void _reviewNextDecision() {
    final OperatingDecisionReceipt? decision = ref
        .read(nexusDecisionProvider)
        .intelligence
        ?.decision;
    if (decision != null) {
      unawaited(
        ref
            .read(decisionOutcomeActionsProvider)
            .record(
              receipt: decision,
              kind: DecisionOutcomeKind.accepted,
              surface: 'nexus',
              detail: 'Opened Smart Planner from the selected time block.',
            ),
      );
    }
    unawaited(
      ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstNexusReview),
    );
    goToAppView(context, ref, AppView.smartPlanner);
  }

  void _recordDecisionShown(OperatingDecisionReceipt? decision) {
    if (decision == null ||
        decision.isExpired ||
        _shownDecisionId == decision.decisionId) {
      return;
    }
    _shownDecisionId = decision.decisionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shownDecisionId != decision.decisionId) return;
      unawaited(
        ref
            .read(decisionOutcomeActionsProvider)
            .record(
              receipt: decision,
              kind: DecisionOutcomeKind.shown,
              surface: 'nexus',
            ),
      );
    });
  }
}
