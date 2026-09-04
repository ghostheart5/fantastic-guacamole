part of 'nexus_screen.dart';

class _NexusHeader extends ConsumerWidget {
  const _NexusHeader({required this.profile});

  final ProfileState profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationsProvider);
    final routes = ref.watch(routeSurfaceProvider);
    final double width = MediaQuery.sizeOf(context).width;
    final double statusFontSize = width < Breakpoints.ultraCompact
        ? AppSizes.fontMicro
        : width < Breakpoints.compact
        ? AppSizes.fontXs
        : AppSizes.fontSm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'NEXUS',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your day, resolved into one clear move.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppSizes.fontBodyLg,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ADAPTIVE LOGIC CORE',
                      style: TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: AppSizes.fontMicro,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeaderControl(
                semanticLabel: 'Open notifications',
                accent: AppColors.neonCyan,
                onTap: () => context.push(routes.notifications),
                child: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderControl(
                semanticLabel: 'Log out',
                accent: AppColors.neonViolet,
                onTap: () => unawaited(_signOut(context, ref)),
                child: const Icon(Icons.logout_rounded, size: 19),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('nexus-context-settings'),
              onPressed: () {
                ref.read(personContextSettingsEntryProvider.notifier).request();
                goToAppView(context, ref, AppView.settings);
              },
              icon: const Icon(Icons.manage_accounts_outlined, size: 18),
              label: const Text('CONTEXT'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.memoryAmber,
                minimumSize: const Size(
                  AppSizes.touchTarget,
                  AppSizes.touchTarget,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name.isEmpty
                ? 'TODAY IS READY  ·  LVL ${profile.level}  ·  ${profile.streak}D STREAK'
                : '${profile.name.toUpperCase()}  ·  LVL ${profile.level}  ·  ${profile.streak}D STREAK',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: statusFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final routes = ref.read(routeSurfaceProvider);
    try {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go(routes.login);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }
}

class _HeaderControl extends StatelessWidget {
  const _HeaderControl({
    required this.semanticLabel,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final Color accent;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bgSecondary.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: .42)),
        ),
        child: IconTheme(
          data: IconThemeData(color: accent),
          child: child,
        ),
      ),
    );
  }
}

class _NexusVitals extends StatelessWidget {
  const _NexusVitals({
    required this.energy,
    required this.fatigue,
    required this.momentum,
    required this.hasObservedEnergy,
    required this.hasObservedClarity,
    required this.hasMomentumEvidence,
    required this.pulse,
  });

  final double energy;
  final double fatigue;
  final double momentum;
  final bool hasObservedEnergy;
  final bool hasObservedClarity;
  final bool hasMomentumEvidence;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final String momentumLabel = !hasMomentumEvidence
        ? 'LEARNING'
        : momentum >= .72
        ? 'STRONG'
        : momentum >= .45
        ? 'STEADY'
        : 'BUILDING';
    return Semantics(
      container: true,
      label:
          '${hasObservedEnergy ? 'Energy ${(energy * 100).round()} percent' : 'Energy unmeasured'}. '
          '${hasObservedClarity ? 'Clarity ${((1 - fatigue) * 100).round()} percent' : 'Clarity not checked'}. '
          'Momentum $momentumLabel.',
      child: Row(
        children: <Widget>[
          Expanded(
            child: _VitalMetric(
              label: 'ENERGY',
              value: hasObservedEnergy
                  ? '${(energy * 100).round()}%'
                  : 'UNMEASURED',
              accent: AppColors.neonCyan,
              pulse: pulse,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _VitalMetric(
              label: 'CLARITY',
              value: hasObservedClarity
                  ? '${((1 - fatigue) * 100).round()}%'
                  : 'NOT CHECKED',
              accent: AppColors.neonViolet,
              pulse: pulse,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _VitalMetric(
              label: 'MOMENTUM',
              value: momentumLabel,
              accent: AppColors.memoryAmber,
              pulse: pulse,
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalMetric extends StatelessWidget {
  const _VitalMetric({
    required this.label,
    required this.value,
    required this.accent,
    required this.pulse,
  });

  final String label;
  final String value;
  final Color accent;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: AppSizes.fontMicro,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: accent.withValues(alpha: .84 + pulse * .16),
              fontSize: AppSizes.fontBodyLg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartPlannerSuggestion extends StatelessWidget {
  const _SmartPlannerSuggestion({
    required this.blocks,
    required this.nextBlock,
    required this.decisionModel,
    required this.completingTaskIds,
    required this.onCompleteTask,
    required this.onRetry,
    required this.onReviewPlan,
    required this.onIgnoreContext,
  });

  final AsyncValue<List<TimeBlock>> blocks;
  final TimeBlock? nextBlock;
  final NexusDecisionModel decisionModel;
  final Set<String> completingTaskIds;
  final Future<void> Function(String taskId) onCompleteTask;
  final VoidCallback onRetry;
  final VoidCallback onReviewPlan;
  final ValueChanged<OperatingDecisionReceipt> onIgnoreContext;

  @override
  Widget build(BuildContext context) {
    final OperatingDecisionReceipt? decision =
        decisionModel.intelligence?.decision;
    final List<TimeBlock>? availableBlocks = blocks.asData?.value;
    final TimeBlock? block =
        nextBlock ??
        (availableBlocks != null && availableBlocks.isNotEmpty
            ? availableBlocks.first
            : null);
    final Color accent = _statusAccent(decisionModel.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading(
          eyebrow: 'CURRENT DECISION',
          title: 'Recommended next move',
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 9),
        _GlassPanel(
          accent: accent,
          child: blocks.hasError && decision == null
              ? _PlannerUnavailable(onRetry: onRetry)
              : _PlannerSuggestionContent(
                  decisionModel: decisionModel,
                  decision: decision,
                  block: block,
                  completing:
                      block != null && completingTaskIds.contains(block.taskId),
                  onCompleteTask: onCompleteTask,
                  onReviewPlan: onReviewPlan,
                  onIgnoreContext: decision == null
                      ? null
                      : () => onIgnoreContext(decision),
                ),
        ),
      ],
    );
  }
}

class _PlannerSuggestionContent extends StatelessWidget {
  const _PlannerSuggestionContent({
    required this.decisionModel,
    required this.decision,
    required this.block,
    required this.completing,
    required this.onCompleteTask,
    required this.onReviewPlan,
    required this.onIgnoreContext,
  });

  final NexusDecisionModel decisionModel;
  final OperatingDecisionReceipt? decision;
  final TimeBlock? block;
  final bool completing;
  final Future<void> Function(String taskId) onCompleteTask;
  final VoidCallback onReviewPlan;
  final VoidCallback? onIgnoreContext;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final String title = _firstNonEmpty(<String?>[
      decision?.recommendedAction,
      block?.title,
      'Build one clear next step',
    ]);
    final String rationale = _firstNonEmpty(<String?>[
      decision?.whyItMatters,
      decision?.rationale,
      block == null
          ? 'Add a task in Creator so Smart Planner can rank real work.'
          : 'This scheduled task is the nearest concrete commitment.',
    ]);
    final String? confidenceLabel = decision == null
        ? null
        : l10n.provisionalEvidenceConfidenceLabel(decision!.confidence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StatusLabel(
              label: decisionModel.statusLabel,
              accent: _statusAccent(decisionModel.status),
            ),
            if (confidenceLabel != null) ...<Widget>[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  confidenceLabel,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: AppSizes.fontCaption,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 13),
        Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rationale,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: AppSizes.fontBodyLg,
            height: 1.42,
          ),
        ),
        if (decision?.personContextExplanations.isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            key: const Key('nexus-person-context-why'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: .08),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: .28),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Why this changed: ${decision!.personContextExplanations.join(' ')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: AppSizes.fontBody,
                    height: 1.4,
                  ),
                ),
                if (onIgnoreContext != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('nexus-ignore-person-context'),
                      onPressed: onIgnoreContext,
                      child: const Text('Ignore this context for now'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (block != null) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.neonViolet,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${_formatDateTime(block!.start)}  →  ${_formatTime(block!.end)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: onReviewPlan,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Review suggestion'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                  backgroundColor: AppColors.neonCyan,
                  foregroundColor: const Color(0xFF001318),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (block != null && !block!.completed) ...<Widget>[
              const SizedBox(width: 9),
              Semantics(
                button: true,
                label: l10n.completeTaskLabel(block!.title),
                child: OutlinedButton(
                  onPressed: completing
                      ? null
                      : () => unawaited(onCompleteTask(block!.taskId)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(92, AppSizes.touchTarget),
                    foregroundColor: AppColors.neonViolet,
                    side: BorderSide(
                      color: AppColors.neonViolet.withValues(alpha: .6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: completing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.text(ChronoSparkString.complete)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PlannerUnavailable extends StatelessWidget {
  const _PlannerUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'The current suggestion could not load from local planning evidence.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        IconButton(
          onPressed: onRetry,
          tooltip: 'Retry',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.recallRed),
        ),
      ],
    );
  }
}

class _CurrentFocusSection extends StatelessWidget {
  const _CurrentFocusSection({
    required this.goals,
    required this.tasks,
    required this.notes,
    required this.nextBlock,
    required this.onOpenGoal,
    required this.onOpenTask,
    required this.onOpenNote,
  });

  final List<GoalEntity> goals;
  final AsyncValue<List<TaskEntity>> tasks;
  final AsyncValue<List<NoteEntity>> notes;
  final TimeBlock? nextBlock;
  final VoidCallback onOpenGoal;
  final VoidCallback onOpenTask;
  final VoidCallback onOpenNote;

  @override
  Widget build(BuildContext context) {
    final TaskEntity? currentTask = _selectCurrentTask(
      tasks.asData?.value ?? const <TaskEntity>[],
      nextBlock,
    );
    final GoalEntity? currentGoal = _selectCurrentGoal(goals, currentTask);
    final NoteEntity? currentNote = _selectCurrentNote(
      notes.asData?.value ?? const <NoteEntity>[],
      currentTask,
      currentGoal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading(
          eyebrow: 'CURRENT PRIORITIES',
          title: 'Goal · task · note',
          icon: Icons.center_focus_strong_rounded,
          accent: AppColors.neonViolet,
        ),
        const SizedBox(height: 9),
        _GlassPanel(
          accent: AppColors.neonViolet,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              _FocusRow(
                icon: Icons.flag_outlined,
                label: 'GOAL',
                title: currentGoal?.title ?? 'No active goal',
                detail: currentGoal == null
                    ? 'Create a goal to connect today’s work to an outcome.'
                    : _goalDetail(currentGoal),
                accent: AppColors.neonViolet,
                onTap: onOpenGoal,
              ),
              const _PanelDivider(),
              _FocusRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'TASK',
                title:
                    currentTask?.title ?? nextBlock?.title ?? 'No active task',
                detail: currentTask != null
                    ? _taskDetail(currentTask)
                    : nextBlock != null
                    ? _formatDateTime(nextBlock!.start)
                    : 'Create a task and schedule it when you are ready.',
                accent: AppColors.neonCyan,
                onTap: onOpenTask,
              ),
              const _PanelDivider(),
              _FocusRow(
                icon: Icons.sticky_note_2_outlined,
                label: 'NOTE',
                title: notes.isLoading
                    ? 'Loading note…'
                    : currentNote?.title ?? 'No current note',
                detail: currentNote == null
                    ? 'Capture useful context without turning it into another task.'
                    : _noteDetail(currentNote),
                accent: AppColors.memoryAmber,
                onTap: onOpenNote,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      semanticLabel: 'Open $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: .28)),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: AppSizes.fontCaption,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: accent.withValues(alpha: .75),
            ),
          ],
        ),
      ),
    );
  }
}
