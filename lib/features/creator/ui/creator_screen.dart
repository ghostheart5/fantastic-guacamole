import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_event_bridge.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/state/providers/voice_command_handoff_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key});

  @override
  ConsumerState<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends ConsumerState<CreatorScreen> {
  CreatorWorkspaceMode _mode = CreatorWorkspaceMode.tasks;
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _goalTitleController = TextEditingController();
  final TextEditingController _memoryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _lastAppliedHandoffAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ref.read(missionTutorialEnabledProvider)) {
        ref.read(missionEventBridgeProvider).reportCreatorOpened();
      }
    });
  }

  TextEditingController get _titleController {
    if (_mode == CreatorWorkspaceMode.goals) {
      return _goalTitleController;
    }
    return _taskTitleController;
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _goalTitleController.dispose();
    _memoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyVoiceHandoff(VoiceCommandHandoff handoff) {
    if (_lastAppliedHandoffAt == handoff.createdAt) {
      return;
    }
    _lastAppliedHandoffAt = handoff.createdAt;

    final CreatorWorkspaceMode targetMode = handoff.isGoalIntent
        ? CreatorWorkspaceMode.goals
        : CreatorWorkspaceMode.tasks;
    if (targetMode == CreatorWorkspaceMode.goals) {
      _goalTitleController.text = handoff.suggestedTitle;
      _goalTitleController.selection = TextSelection.collapsed(
        offset: _goalTitleController.text.length,
      );
    } else {
      _titleController.text = handoff.suggestedTitle;
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
    }

    if (handoff.isMemoryIntent) {
      _memoryController.text = handoff.originalText.trim();
    }

    if (_mode != targetMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _mode = targetMode;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceHandoff = ref.watch(voiceCommandHandoffProvider);
    final bool missionTutorialEnabled = ref.watch(
      missionTutorialEnabledProvider,
    );
    if (voiceHandoff != null) {
      _applyVoiceHandoff(voiceHandoff);
    }

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
                if (voiceHandoff != null) ...[
                  _VoiceCommandHandoffCard(
                    handoff: voiceHandoff,
                    onClear: () =>
                        ref.read(voiceCommandHandoffProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    SmartPressable(
                      onTap: () => ref.read(appFlowProvider.notifier).toNexus(),
                      child: Container(
                        width: 36,
                        height: 36,
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
                              'Creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'Create, schedule, and review items',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (missionTutorialEnabled) ...[
                  const _CreatorMissionPanel(),
                  const SizedBox(height: 16),
                ],
                DynamicForm(
                  workspaceMode: _mode,
                  taskTitleController: _taskTitleController,
                  goalTitleController: _goalTitleController,
                  memoryController: _memoryController,
                  notesController: _notesController,
                  onSubmit: (data) async {
                    final bool shouldAutoOpenTimeline =
                        !ref.read(creatorFirstItemCreatedProvider);
                    final savedKind = await ref
                        .read(creatorActionsProvider)
                        .createEntry(data);
                    if (missionTutorialEnabled) {
                      await ref
                          .read(missionEventBridgeProvider)
                          .reportGoalCreated();
                    }
                    if (savedKind == CreatorSavedKind.task) {
                      await ref
                          .read(localMetricsAccumulatorProvider)
                          .recordTaskCreated();
                    }
                    ref.invalidate(tasksProvider);
                    ref.invalidate(goalProgressProvider);

                    if (context.mounted) {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              shouldAutoOpenTimeline
                                  ? 'First item created. Reviewing it on your timeline...'
                                  : 'Item saved.',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'REVIEW TIMELINE',
                              onPressed: () {
                                if (!context.mounted) {
                                  return;
                                }
                                ref.read(appFlowProvider.notifier).toTimeline();
                              },
                            ),
                          ),
                        );

                      if (shouldAutoOpenTimeline) {
                        // First successful create should immediately reinforce
                        // the Create -> Timeline review loop.
                        ref.read(appFlowProvider.notifier).toTimeline();
                      }
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

class _CreatorMissionPanel extends ConsumerWidget {
  const _CreatorMissionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MissionState> missionAsync = ref.watch(
      missionStateProvider,
    );
    return missionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (MissionState missionState) {
        final MissionId? activeMissionId = missionState.activeMissionId;
        String? badge;
        String? title;

        if (activeMissionId == MissionId.createFirstGoal) {
          badge = 'STEP 1';
          title = 'Create your first item in Creator.';
        } else if (activeMissionId == MissionId.configureFirstItem) {
          badge = 'STEP 2';
          title = 'Add timing details, then save it.';
        }

        if (badge == null || title == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                badge,
                style: const TextStyle(
                  color: AppColors.neonCyan,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceCommandHandoffCard extends StatelessWidget {
  const _VoiceCommandHandoffCard({
    required this.handoff,
    required this.onClear,
  });

  final VoiceCommandHandoff handoff;
  final VoidCallback onClear;

  String get _label {
    if (handoff.isTaskIntent) {
      return 'VOICE TASK';
    }
    if (handoff.isGoalIntent) {
      return 'VOICE GOAL';
    }
    if (handoff.isMemoryIntent) {
      return 'VOICE MEMORY';
    }
    return 'VOICE COMMAND';
  }

  String get _instruction {
    if (handoff.isTaskIntent) {
      return 'Use this captured title to create a task.';
    }
    if (handoff.isGoalIntent) {
      return 'Use this captured title to create a goal.';
    }
    if (handoff.isMemoryIntent) {
      return 'Use this captured text to capture a memory.';
    }
    return 'Voice command routed into Creator.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xEE07111F),
            AppColors.neonCyan.withValues(alpha: 0.10),
            AppColors.neonViolet.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: const TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            handoff.suggestedTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _instruction,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'CLEAR VOICE HANDOFF',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
