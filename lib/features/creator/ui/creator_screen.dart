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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xF207111F), Color(0xEC0B1428)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.38),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      SmartPressable(
                        onTap: () => goToAppView(context, ref, AppView.nexus),
                        semanticLabel: 'Back to Nexus',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.neonCyan.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.neonCyan.withValues(alpha: 0.55),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.neonCyan,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Container(
                        width: 3,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              AppColors.neonCyan,
                              AppColors.neonViolet,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: <Color>[
                                  AppColors.neonCyan,
                                  Color(0xFFB9A8FF),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'CREATOR',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Turn intention into connected action',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                letterSpacing: 0.45,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD7DFF0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                DynamicForm(
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
