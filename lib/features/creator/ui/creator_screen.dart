import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
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
    final CreatorHandshakeState handshake = ref.watch(creatorHandshakeProvider);
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
                if (plannerDraft != null) ...[
                  _PlannerDraftPreviewCard(
                    draft: plannerDraft,
                    onDiscard: () =>
                        ref.read(creatorDraftPreviewProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (handshake.isReviewing) ...[
                  _CreatorHandshakePreviewCard(
                    state: handshake,
                    onToggle: (String operationId, bool selected) => ref
                        .read(creatorHandshakeProvider.notifier)
                        .toggleOperation(operationId, selected: selected),
                    onEdit: () => ref
                        .read(creatorHandshakeProvider.notifier)
                        .cancelPreview(),
                    onCancel: () => ref
                        .read(creatorHandshakeProvider.notifier)
                        .cancelPreview(),
                    onConfirm: handshake.canConfirm
                        ? () async {
                            final CreatorHandshakeState result = await ref
                                .read(creatorHandshakeProvider.notifier)
                                .confirm();
                            if (result.receipt != null && context.mounted) {
                              tutorialDraft.reset();
                              ref
                                  .read(creatorDraftPreviewProvider.notifier)
                                  .clear();
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Confirmed and saved exactly once. Undo is available here.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                ] else if (handshake.receipt != null) ...[
                  _CreatorHandshakeResultCard(
                    state: handshake,
                    onUndo:
                        handshake.phase == CreatorHandshakePhase.applied ||
                            handshake.phase == CreatorHandshakePhase.idempotent
                        ? () async {
                            await ref
                                .read(creatorHandshakeProvider.notifier)
                                .undo();
                          }
                        : null,
                    onTimeline: () =>
                        goToAppView(context, ref, AppView.timeline),
                    onNewItem: () => ref
                        .read(creatorHandshakeProvider.notifier)
                        .clearResult(),
                  ),
                  const SizedBox(height: 16),
                ],
                Offstage(
                  offstage: handshake.isReviewing,
                  child: DynamicForm(
                    key: ValueKey<String>(
                      'creator-form-${handshake.formRevision}',
                    ),
                    initialDraftId: plannerDraft?.id,
                    initialTitle: plannerDraft?.title,
                    initialDescription: plannerDraft?.description,
                    submitLabel: 'REVIEW CHANGES',
                    clearAfterSubmit: false,
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
                    onSubmit: (data) => ref
                        .read(creatorHandshakeProvider.notifier)
                        .stage(
                          data: data,
                          source: plannerDraft == null
                              ? CreatorHandshakeSource.creator
                              : CreatorHandshakeSource.smartPlanner,
                        ),
                  ),
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
            'Nothing has been saved. Review and edit the prefilled form, then press REVIEW CHANGES to open Creator confirmation.',
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

class _CreatorHandshakePreviewCard extends StatelessWidget {
  const _CreatorHandshakePreviewCard({
    required this.state,
    required this.onToggle,
    required this.onEdit,
    required this.onCancel,
    required this.onConfirm,
  });

  final CreatorHandshakeState state;
  final void Function(String operationId, bool selected) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function()? onConfirm;

  @override
  Widget build(BuildContext context) {
    final CreatorHandshakePreview preview = state.preview!;
    return Container(
      key: const Key('creator-handshake-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              state.phase == CreatorHandshakePhase.stale ||
                  state.phase == CreatorHandshakePhase.expired
              ? AppColors.memoryAmber.withValues(alpha: 0.7)
              : AppColors.neonCyan.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIRM CREATOR CHANGES',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nothing is saved until you confirm the selected operation below.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          _HandshakeBindingLine(
            label: 'Account binding',
            value: _short(preview.accountScopeId),
          ),
          _HandshakeBindingLine(
            label: 'Domain version',
            value: _short(preview.baseDomainRevision),
          ),
          _HandshakeBindingLine(
            label: 'Displayed diff',
            value: _short(preview.displayedDiffDigest),
          ),
          _HandshakeBindingLine(
            label: 'Expires',
            value: TimeOfDay.fromDateTime(
              preview.expiresAt.toLocal(),
            ).format(context),
          ),
          const SizedBox(height: 10),
          ...preview.operations.map((CreatorMutationOperation operation) {
            final CreatorTaskMutation task = operation.task;
            final bool selected = preview.selectedOperationIds.contains(
              operation.operationId,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white.withValues(alpha: 0.035),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected
                        ? AppColors.neonCyan.withValues(alpha: 0.35)
                        : Colors.white12,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  key: ValueKey<String>(
                    'creator-operation-${operation.operationId}',
                  ),
                  value: selected,
                  onChanged: state.phase == CreatorHandshakePhase.confirming
                      ? null
                      : (bool? value) =>
                            onToggle(operation.operationId, value ?? false),
                  activeColor: AppColors.neonCyan,
                  checkColor: const Color(0xFF03101B),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                  title: Text(
                    operation.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _diff('Title', 'Not present', task.title),
                        _diff('Type', 'Not present', task.creatorKind),
                        _diff(
                          'Priority',
                          'Not present',
                          '${task.priority} / 5',
                        ),
                        _diff(
                          'Schedule',
                          'Not present',
                          task.scheduledFor?.toLocal().toString() ??
                              'Unscheduled',
                        ),
                        _diff(
                          'Repeat',
                          'Not present',
                          task.recurrenceRule.name,
                        ),
                        if (task.description?.isNotEmpty ?? false)
                          _diff(
                            'Description',
                            'Not present',
                            task.description!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (state.message != null) ...[
            const SizedBox(height: 2),
            Text(
              state.message!,
              key: const Key('creator-handshake-message'),
              style: TextStyle(
                color:
                    state.phase == CreatorHandshakePhase.stale ||
                        state.phase == CreatorHandshakePhase.expired ||
                        state.phase == CreatorHandshakePhase.conflict
                    ? AppColors.memoryAmber
                    : Colors.white60,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('creator-confirm-selected'),
              onPressed: onConfirm == null
                  ? null
                  : () async {
                      await onConfirm!();
                    },
              child: Text(
                state.phase == CreatorHandshakePhase.confirming
                    ? 'CONFIRMING…'
                    : 'CONFIRM SELECTED',
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit draft')),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _diff(String field, String before, String after) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        '$field: $before → $after',
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }

  static String _short(String value) =>
      value.length <= 18 ? value : '${value.substring(0, 18)}…';
}

class _CreatorHandshakeResultCard extends StatelessWidget {
  const _CreatorHandshakeResultCard({
    required this.state,
    required this.onUndo,
    required this.onTimeline,
    required this.onNewItem,
  });

  final CreatorHandshakeState state;
  final Future<void> Function()? onUndo;
  final VoidCallback onTimeline;
  final VoidCallback onNewItem;

  @override
  Widget build(BuildContext context) {
    final CreatorHandshakeReceipt receipt = state.receipt!;
    final bool undone = state.phase == CreatorHandshakePhase.undone;
    return Container(
      key: const Key('creator-handshake-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (undone ? AppColors.memoryAmber : AppColors.neonCyan).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (undone ? AppColors.memoryAmber : AppColors.neonCyan)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            undone ? 'CREATION UNDONE' : 'CONFIRMED CREATOR RECEIPT',
            style: TextStyle(
              color: undone ? AppColors.memoryAmber : AppColors.neonCyan,
              fontSize: 11,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirmation: ${receipt.confirmationTokenId}\n'
            'Operations: ${receipt.appliedOperationIds.length}\n'
            'Result version: ${_CreatorHandshakePreviewCard._short(receipt.resultingDomainRevision)}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onUndo != null)
                OutlinedButton.icon(
                  key: const Key('creator-undo-confirmed'),
                  onPressed: () async {
                    await onUndo!();
                  },
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Undo creation'),
                ),
              if (!undone)
                ElevatedButton(
                  onPressed: onTimeline,
                  child: const Text('Open Timeline'),
                ),
              TextButton(onPressed: onNewItem, child: const Text('New item')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HandshakeBindingLine extends StatelessWidget {
  const _HandshakeBindingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
