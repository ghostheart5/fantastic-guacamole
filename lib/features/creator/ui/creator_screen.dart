import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatorDraftPreview? plannerDraft = ref.watch(
      creatorDraftPreviewProvider,
    );
    final AdaptiveGuidanceState? guidanceState = ref
        .watch(adaptiveGuidanceProvider)
        .asData
        ?.value;
    final bool guidedFirstTask =
        guidanceState != null &&
        (!guidanceState.has(GuidanceMilestone.firstItem) ||
            !guidanceState.has(GuidanceMilestone.firstSchedule));
    final CreatorTutorialDraftNotifier tutorialDraft = ref.read(
      creatorTutorialDraftProvider.notifier,
    );
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgCreatorIntent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () => goToAppView(context, ref, AppView.nexus),
                      semanticLabel: 'Back to Smart Planner',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                AppColors.neonCyan,
                                AppColors.neonViolet,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'CREATOR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'INTENTION → CONNECTED ACTION',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (plannerDraft != null) ...[
                  _PlannerDraftPreviewCard(
                    draft: plannerDraft,
                    onDiscard: () =>
                        ref.read(creatorDraftPreviewProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 16),
                ],
                DynamicForm(
                  initialDraftId: plannerDraft?.id,
                  initialTitle: plannerDraft?.title,
                  initialDescription: plannerDraft?.description,
                  guidedFirstTask: guidedFirstTask,
                  tutorialController: ref.read(
                    creatorTutorialFormControllerProvider,
                  ),
                  onPickerVisibilityChanged: ref
                      .read(tutorialInteractionPausedProvider.notifier)
                      .set,
                  onTitleValidityChanged: tutorialDraft.setHasTitle,
                  onTypeChosen: tutorialDraft.markTypeChosen,
                  onPriorityChosen: tutorialDraft.markPriorityChosen,
                  onScheduleValidityChanged: tutorialDraft.setHasSchedule,
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createTask(data);
                    try {
                      final AdaptiveGuidanceNotifier guidance = ref.read(
                        adaptiveGuidanceProvider.notifier,
                      );
                      await guidance.record(GuidanceMilestone.firstItem);
                      if (data.scheduledFor != null) {
                        await guidance.record(GuidanceMilestone.firstSchedule);
                      }
                    } catch (_) {
                      // Guidance persistence must never turn a successful save
                      // into a failed Creator action.
                    }
                    try {
                      // TaskActions invalidates the ranked task projection
                      // after persistence. Settle that projection before
                      // Timeline mounts so its first provider watch cannot
                      // trigger a refresh during the destination build.
                      await ref.read(tasksProvider.future);
                    } catch (_) {
                      // The task is already durable. Timeline owns presenting
                      // any projection/read failure without converting the
                      // successful Creator save into a false failure.
                    }
                    tutorialDraft.reset();
                    ref.read(creatorDraftPreviewProvider.notifier).clear();
                    if (context.mounted) {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Captured. Your next step is ready in Timeline.',
                            ),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      goToAppView(context, ref, AppView.timeline);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerDraftPreviewCard extends StatelessWidget {
  const _PlannerDraftPreviewCard({
    required this.draft,
    required this.onDiscard,
  });

  final CreatorDraftPreview draft;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('creator-planner-draft-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLANNER DRAFT PREVIEW',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nothing has been saved. Review and edit the prefilled form, then press FORGE TASK only if you want Creator to save it.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            draft.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${draft.estimatedMinutes} minute ${draft.sourceOption.name} option',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDiscard,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Discard preview'),
          ),
        ],
      ),
    );
  }
}
