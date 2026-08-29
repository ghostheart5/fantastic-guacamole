import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemporalScreenHeader(
                  title: 'Creator',
                  subtitle: 'Turn intention into connected action.',
                  eyebrow: 'Connected action',
                  onBack: () => goToAppView(context, ref, AppView.nexus),
                ),
                const SizedBox(height: 18),
                const TemporalDivider(color: AppColors.memoryAmber),
                const SizedBox(height: 18),
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
                    guidedFirstTask: guidedFirstTask,
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
                            final bool completesGuidedSetup =
                                guidedFirstTask &&
                                (handshake.preview?.selectedOperations.any(
                                      (CreatorMutationOperation operation) =>
                                          operation.task.scheduledFor != null,
                                    ) ??
                                    false);
                            final CreatorHandshakeState result = await ref
                                .read(creatorHandshakeProvider.notifier)
                                .confirm();
                            if (result.receipt != null && context.mounted) {
                              tutorialDraft.reset();
                              ref
                                  .read(creatorDraftPreviewProvider.notifier)
                                  .clear();
                              if (completesGuidedSetup) {
                                goToAppView(context, ref, AppView.timeline);
                                return;
                              }
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
    return TemporalGlassSurface(
      key: const Key('creator-planner-draft-preview'),
      accent: AppColors.neonCyan,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLANNER DRAFT PREVIEW',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              letterSpacing: 0,
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
          TemporalActionButton(
            onPressed: onDiscard,
            icon: Icons.close_rounded,
            label: 'Discard preview',
            filled: false,
          ),
        ],
      ),
    );
  }
}

class _CreatorHandshakePreviewCard extends StatelessWidget {
  const _CreatorHandshakePreviewCard({
    required this.state,
    required this.guidedFirstTask,
    required this.onToggle,
    required this.onEdit,
    required this.onCancel,
    required this.onConfirm,
  });

  final CreatorHandshakeState state;
  final bool guidedFirstTask;
  final void Function(String operationId, bool selected) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function()? onConfirm;

  @override
  Widget build(BuildContext context) {
    final CreatorHandshakePreview preview = state.preview!;
    final Color accent =
        state.phase == CreatorHandshakePhase.stale ||
            state.phase == CreatorHandshakePhase.expired
        ? AppColors.memoryAmber
        : AppColors.neonCyan;
    return TemporalGlassSurface(
      key: const Key('creator-handshake-preview'),
      padding: const EdgeInsets.all(16),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIRM CREATOR CHANGES',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 11,
              letterSpacing: 0,
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
                  borderRadius: BorderRadius.circular(8),
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
                      letterSpacing: 0,
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
          KeyedSubtree(
            key: guidedFirstTask
                ? FirstRunTutorialTargets.creatorConfirm
                : null,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('creator-confirm-selected'),
                onPressed: onConfirm == null
                    ? null
                    : () async {
                        await onConfirm!();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonCyan,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  state.phase == CreatorHandshakePhase.confirming
                      ? 'CONFIRMING…'
                      : 'CONFIRM SELECTED',
                ),
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
    final Color accent = undone ? AppColors.memoryAmber : AppColors.neonCyan;
    return TemporalGlassSurface(
      key: const Key('creator-handshake-result'),
      padding: const EdgeInsets.all(16),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            undone ? 'CREATION UNDONE' : 'CONFIRMED CREATOR RECEIPT',
            style: TextStyle(
              color: undone ? AppColors.memoryAmber : AppColors.neonCyan,
              fontSize: 11,
              letterSpacing: 0,
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
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('creator-undo-confirmed'),
                    onPressed: () async {
                      await onUndo!();
                    },
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Undo creation'),
                  ),
                ),
              if (!undone)
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onTimeline,
                    icon: const Icon(Icons.timeline_rounded, size: 18),
                    label: const Text('Open Timeline'),
                  ),
                ),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: onNewItem,
                  child: const Text('New item'),
                ),
              ),
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
