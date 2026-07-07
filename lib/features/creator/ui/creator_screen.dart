import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/widgets/micro_tutorial_card.dart';
import 'package:fantastic_guacamole/tutorial/widgets/show_me_again_button.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorScreen extends ConsumerWidget {
  const CreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/creator_bg.jpg',
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
                      onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
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
                              colors: [AppColors.neonCyan, AppColors.neonViolet],
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
                            'OPTIONAL ENTRY FORGE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _CreatorTutorialPanel(),
                const SizedBox(height: 16),
                const _CreatorPurposeCard(),
                const SizedBox(height: 16),
                DynamicForm(
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createTask(data);
                    await ref.read(localMetricsAccumulatorProvider).recordTaskCreated();
                    ref.invalidate(tasksProvider);
                    ref.invalidate(goalProgressProvider);
                    ref.read(tutorialControllerProvider).updateState('has_created_task', true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Entry created.'),
                          action: SnackBarAction(
                            label: 'TRAJECTORY',
                            onPressed: () {
                              ref.read(appFlowProvider.notifier).toPlan();
                            },
                          ),
                        ),
                      );
                      ref.read(appFlowProvider.notifier).toPlan();
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

class _CreatorTutorialPanel extends ConsumerWidget {
  const _CreatorTutorialPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);
    final TutorialStepContent step = TutorialContent.steps.firstWhere(
      (TutorialStepContent content) => content.id == 'creator_workbench',
      orElse: () => TutorialContent.steps.first,
    );

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isStepCompleted(step.id)) {
          return const SizedBox.shrink();
        }

        if (progress.isStepDismissed(step.id)) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ShowMeAgainButton(stepId: step.id, label: 'Show Creator Tutorial Again'),
          );
        }

        return MicroTutorialCard(
          step: step,
          onComplete: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
          onDismiss: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
        );
      },
    );
  }
}

class _CreatorPurposeCard extends StatelessWidget {
  const _CreatorPurposeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.14)),
      ),
      child: const Text(
        'Creator is optional. Use Smart Coach, Day Plan, and Flowmap for guided workflows. Use Creator when you want direct, manual task forging.',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
      ),
    );
  }
}
