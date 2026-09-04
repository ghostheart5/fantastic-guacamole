import 'dart:async';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/usecases/apply_learning_feedback.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/state/providers/nexus_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

part 'nexus_screen.widgets.dart';
part 'nexus_screen.timeline_widgets.dart';

class NexusScreen extends ConsumerStatefulWidget {
  const NexusScreen({super.key});

  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final Set<String> _completingTaskIds = <String>{};

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
      unawaited(_pulse.repeat(reverse: true));
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
    final siState = ref.watch(consentedHumanContextProvider).siState;
    final double energy = siState.energy;
    final double fatigue = siState.fatigue;
    final NexusDecisionModel decisionModel = ref.watch(nexusDecisionProvider);
    final LearningFeedbackChange? learningChange = ref.watch(
      latestDecisionLearningChangeProvider,
    );
    final AsyncValue<List<TimeBlock>> nexusBlocks = ref.watch(
      nexusTimeBlocksProvider,
    );
    final TimeBlock? nextBlock = ref.watch(nextNexusTimeBlockProvider);
    final List<GoalEntity> goals = ref.watch(goalsProvider);
    final AsyncValue<List<TaskEntity>> tasks = ref.watch(tasksProvider);
    final AsyncValue<List<NoteEntity>> notes = ref.watch(notesProvider);
    final TrajectorySummaryView trajectory = ref.watch(
      trajectorySummaryProvider,
    );
    final List<TimelineEventEntity> timeline = ref.watch(timelineProvider);
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgNexus,
      overlayOpacity: .54,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _NexusHeader(profile: profile)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _NexusVitals(
                      energy: energy,
                      fatigue: fatigue,
                      momentum: trajectory.momentum,
                      hasObservedEnergy: siState.hasObservedEnergy,
                      hasObservedClarity: siState.hasObservedFatigue,
                      hasMomentumEvidence: trajectory.completedTasks >= 3,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
              if (learningChange != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _LearningChangePanel(
                      change: learningChange,
                      onHelpful: learningChange.isCorrection
                          ? null
                          : () => _correctLatestLearning(
                              learningChange,
                              DecisionOutcomeKind.accepted,
                            ),
                      onNotHelpful: learningChange.isCorrection
                          ? null
                          : () => _correctLatestLearning(
                              learningChange,
                              DecisionOutcomeKind.rejected,
                            ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SmartPlannerSuggestion(
                    blocks: nexusBlocks,
                    nextBlock: nextBlock,
                    decisionModel: decisionModel,
                    completingTaskIds: _completingTaskIds,
                    onCompleteTask: _completeTimeBlockTask,
                    onRetry: () => ref.invalidate(tasksProvider),
                    onReviewPlan: _reviewNextDecision,
                    onIgnoreContext: _ignoreDecisionContext,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _CurrentFocusSection(
                    goals: goals,
                    tasks: tasks,
                    notes: notes,
                    nextBlock: nextBlock,
                    onOpenGoal: () => goToAppView(context, ref, AppView.goals),
                    onOpenTask: () => _openCreator(CreatorFormKind.task),
                    onOpenNote: () => _openCreator(CreatorFormKind.note),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _TrajectoryReport(
                    summary: trajectory,
                    onOpen: () =>
                        goToAppView(context, ref, AppView.trajectoryEngine),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _TimelineSnapshot(
                    events: timeline,
                    tasks: tasks,
                    onOpen: () => goToAppView(context, ref, AppView.timeline),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreator(CreatorFormKind type) {
    ref.read(creatorNavigationIntentProvider.notifier).open(type);
    goToAppView(context, ref, AppView.creator);
  }

  Future<void> _completeTimeBlockTask(String taskId) async {
    if (_completingTaskIds.contains(taskId)) {
      return;
    }
    setState(() => _completingTaskIds.add(taskId));
    try {
      await ref.read(taskActionsProvider).completeTask(taskId, notify: false);
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
              situation: 'selected time block',
              optionChosen: 'review in Smart Planner',
              recommendationHelped: true,
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

  void _ignoreDecisionContext(OperatingDecisionReceipt decision) {
    if (decision.personContextAppliedSignalIds.isEmpty) return;
    ref
        .read(personContextDecisionIgnoredSignalsProvider.notifier)
        .ignoreForNow(decision.personContextAppliedSignalIds);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This Person Context is ignored for the current use.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _correctLatestLearning(
    LearningFeedbackChange change,
    DecisionOutcomeKind replacement,
  ) async {
    final OperatingDecisionReceipt? receipt = ref
        .read(nexusDecisionProvider)
        .intelligence
        ?.decision;
    if (receipt == null || receipt.decisionId != change.decisionId) return;
    await ref
        .read(decisionOutcomeActionsProvider)
        .correct(
          receipt: receipt,
          originalKind: change.outcomeKind,
          replacementKind: replacement,
          surface: change.surface,
          reason: replacement == DecisionOutcomeKind.accepted
              ? 'The person said this guidance helped.'
              : 'The person said this guidance did not help.',
        );
  }
}
