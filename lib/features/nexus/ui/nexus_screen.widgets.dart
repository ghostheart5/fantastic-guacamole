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
  });

  final AsyncValue<List<TimeBlock>> blocks;
  final TimeBlock? nextBlock;
  final NexusDecisionModel decisionModel;
  final Set<String> completingTaskIds;
  final Future<void> Function(String taskId) onCompleteTask;
  final VoidCallback onRetry;
  final VoidCallback onReviewPlan;

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
  });

  final NexusDecisionModel decisionModel;
  final OperatingDecisionReceipt? decision;
  final TimeBlock? block;
  final bool completing;
  final Future<void> Function(String taskId) onCompleteTask;
  final VoidCallback onReviewPlan;

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
    final int confidence = ((decision?.recommendationConfidence ?? 0) * 100)
        .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StatusLabel(
              label: decisionModel.statusLabel,
              accent: _statusAccent(decisionModel.status),
            ),
            const Spacer(),
            if (decision != null)
              Text(
                '$confidence% evidence confidence',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: AppSizes.fontCaption,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
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
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
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

class _TrajectoryReport extends StatelessWidget {
  const _TrajectoryReport({required this.summary, required this.onOpen});

  final TrajectorySummaryView summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String riskName = summary.riskBand.name;
    final Color accent = switch (riskName) {
      'critical' => AppColors.recallRed,
      'elevated' || 'watch' => AppColors.memoryAmber,
      _ => AppColors.neonViolet,
    };
    final String headline = summary.predictionEvidenceSufficient
        ? summary.predictionOutcome!
        : '${_titleCase(riskName)} pressure signal';
    final String report = summary.predictionEvidenceSufficient
        ? '${((summary.predictionProbability ?? 0) * 100).round()}% observed follow-through across ${summary.predictionSampleSize} outcomes.'
        : _cleanTrajectoryCopy(
            summary.statusDetail.isNotEmpty
                ? summary.statusDetail
                : summary.alert,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          eyebrow: 'TRAJECTORY ENGINE',
          title: 'Current report',
          icon: Icons.insights_rounded,
          accent: accent,
        ),
        const SizedBox(height: 9),
        SmartPressable(
          onTap: onOpen,
          semanticLabel: 'Open Trajectory Engine',
          child: _GlassPanel(
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppSizes.fontTitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  report,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: AppSizes.fontBody,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCell(
                        label: 'PRESSURE',
                        value: '${summary.pressureIndex}%',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: 'MOMENTUM',
                        value: '${(summary.momentum * 100).round()}%',
                        accent: AppColors.neonCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: 'ACTIVE',
                        value: '${summary.pendingTasks}',
                        accent: AppColors.neonViolet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: AppSizes.fontMicro,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: accent,
              fontSize: AppSizes.fontLabelLg,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineSnapshot extends StatelessWidget {
  const _TimelineSnapshot({
    required this.events,
    required this.tasks,
    required this.onOpen,
  });

  final List<TimelineEventEntity> events;
  final AsyncValue<List<TaskEntity>> tasks;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineDisplayItem> summary = _buildTimelineSummary(
      events: events,
      tasks: tasks.asData?.value,
      tasksLoading: tasks.isLoading,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading(
          eyebrow: 'TIMELINE',
          title: 'Today at a glance',
          icon: Icons.timeline_rounded,
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 9),
        _GlassPanel(
          accent: AppColors.neonCyan,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < summary.length; index++) ...<Widget>[
                _TimelineRow(item: summary[index]),
                if (index != summary.length - 1) const _PanelDivider(),
              ],
              const _PanelDivider(),
              SmartPressable(
                onTap: onOpen,
                semanticLabel: 'Open Timeline',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.touchTarget,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Open full Timeline',
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: AppSizes.fontBodyLg,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.neonCyan,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _TimelineDisplayItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accent,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: item.accent.withValues(alpha: .55),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      item.label,
                      style: TextStyle(
                        color: item.accent,
                        fontSize: AppSizes.fontXs,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    if (item.when != null)
                      Text(
                        _formatDateTime(item.when!),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: AppSizes.fontCaption,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.fontBodyLg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.detail.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: AppSizes.fontCaption,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: .24)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: TextStyle(
                  color: accent,
                  fontSize: AppSizes.fontXs,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(15),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      width: double.infinity,
      padding: padding,
      accent: accent,
      opacity: .9,
      child: child,
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withValues(alpha: .07));
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: AppSizes.fontXs,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _TimelineDisplayItem {
  const _TimelineDisplayItem({
    required this.label,
    required this.title,
    required this.detail,
    required this.accent,
    this.when,
  });

  final String label;
  final String title;
  final String detail;
  final Color accent;
  final DateTime? when;
}

List<_TimelineDisplayItem> _buildTimelineSummary({
  required List<TimelineEventEntity> events,
  required List<TaskEntity>? tasks,
  required bool tasksLoading,
}) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime tomorrow = today.add(const Duration(days: 1));
  final List<TimelineEventEntity> newest = List<TimelineEventEntity>.of(events)
    ..sort(
      (TimelineEventEntity first, TimelineEventEntity second) =>
          second.timestamp.compareTo(first.timestamp),
    );
  final TimelineEventEntity? latest = newest.isEmpty ? null : newest.first;
  final List<TaskEntity> active = (tasks ?? const <TaskEntity>[])
      .where((TaskEntity task) => !task.isCompleted && !task.isCanceled)
      .toList(growable: false);
  final Set<String> activeTaskIds = active
      .map((TaskEntity task) => task.id)
      .toSet();
  final List<TaskEntity> dueToday =
      active
          .where((TaskEntity task) {
            final DateTime? deadline = _taskDeadline(task);
            return deadline != null &&
                !deadline.isBefore(today) &&
                deadline.isBefore(tomorrow);
          })
          .toList(growable: false)
        ..sort(_compareTaskDeadlines);
  final List<TaskEntity> overdue =
      active
          .where((TaskEntity task) {
            final DateTime? deadline = _taskDeadline(task);
            return deadline != null && deadline.isBefore(today);
          })
          .toList(growable: false)
        ..sort(_compareTaskDeadlines);
  bool unresolvedEvent(TimelineEventEntity event) =>
      event.status != TimelineEventStatus.completed &&
      event.status != TimelineEventStatus.canceled &&
      event.status != TimelineEventStatus.skipped;
  final List<TimelineEventEntity> dueEvents =
      events
          .where((event) {
            final DateTime? due = event.dueAt;
            return due != null &&
                _eventHasDeadlineSemantics(event) &&
                unresolvedEvent(event) &&
                !activeTaskIds.contains(event.relatedId) &&
                !due.isBefore(today) &&
                due.isBefore(tomorrow);
          })
          .toList(growable: false)
        ..sort(
          (TimelineEventEntity first, TimelineEventEntity second) =>
              first.dueAt!.compareTo(second.dueAt!),
        );
  final List<TimelineEventEntity> overdueEvents =
      events
          .where((event) {
            final DateTime? due = event.dueAt;
            return due != null &&
                _eventHasDeadlineSemantics(event) &&
                unresolvedEvent(event) &&
                !activeTaskIds.contains(event.relatedId) &&
                due.isBefore(today);
          })
          .toList(growable: false)
        ..sort(
          (TimelineEventEntity first, TimelineEventEntity second) =>
              first.dueAt!.compareTo(second.dueAt!),
        );

  final _TimelineDisplayItem latestItem = latest == null
      ? const _TimelineDisplayItem(
          label: 'LAST ADDED',
          title: 'No recent activity',
          detail: 'Your latest Timeline addition will appear here.',
          accent: AppColors.memoryAmber,
        )
      : _TimelineDisplayItem(
          label: 'LAST ADDED',
          title: _latestAdditionTitle(latest),
          detail: _latestAdditionDetail(latest),
          when: latest.timestamp,
          accent: AppColors.memoryAmber,
        );

  final _TimelineDisplayItem todayItem;
  if (tasksLoading && tasks == null) {
    todayItem = const _TimelineDisplayItem(
      label: 'DUE TODAY',
      title: 'Checking today’s schedule…',
      detail: 'Your current commitments are still loading.',
      accent: AppColors.neonCyan,
    );
  } else if (dueToday.isEmpty && dueEvents.isEmpty) {
    todayItem = _TimelineDisplayItem(
      label: 'DUE TODAY',
      title: overdue.isEmpty && overdueEvents.isEmpty
          ? 'Take a break'
          : 'Nothing is due today',
      detail: overdue.isEmpty && overdueEvents.isEmpty
          ? 'Nothing is due today.'
          : 'Review the overdue item below before taking a break.',
      accent: AppColors.neonCyan,
    );
  } else {
    final int dueCount = dueToday.length + dueEvents.length;
    final TaskEntity? firstTask = dueToday.isEmpty ? null : dueToday.first;
    final TimelineEventEntity? firstEvent = dueEvents.isEmpty
        ? null
        : dueEvents.first;
    todayItem = _TimelineDisplayItem(
      label: 'DUE TODAY',
      title: firstTask?.title ?? firstEvent!.title,
      detail: dueCount == 1
          ? 'One commitment is due today.'
          : '$dueCount commitments are due today.',
      when: firstTask == null ? firstEvent!.dueAt : _taskDeadline(firstTask),
      accent: AppColors.neonCyan,
    );
  }

  final _TimelineDisplayItem overdueItem =
      overdue.isEmpty && overdueEvents.isEmpty
      ? const _TimelineDisplayItem(
          label: 'OVERDUE',
          title: 'You’re all caught up',
          detail: 'Nothing is overdue.',
          accent: AppColors.neonViolet,
        )
      : _TimelineDisplayItem(
          label: 'OVERDUE',
          title: overdue.isNotEmpty
              ? overdue.first.title
              : overdueEvents.first.title,
          detail: overdue.length + overdueEvents.length == 1
              ? 'One commitment needs attention.'
              : '${overdue.length + overdueEvents.length} commitments need attention.',
          when: overdue.isNotEmpty
              ? _taskDeadline(overdue.first)
              : overdueEvents.first.dueAt,
          accent: AppColors.recallRed,
        );

  return <_TimelineDisplayItem>[latestItem, todayItem, overdueItem];
}

DateTime? _taskDeadline(TaskEntity task) => task.dueDate;

int _compareTaskDeadlines(TaskEntity first, TaskEntity second) =>
    _taskDeadline(first)!.compareTo(_taskDeadline(second)!);

bool _eventHasDeadlineSemantics(TimelineEventEntity event) =>
    switch (event.type) {
      TimelineEventType.deadline ||
      TimelineEventType.goal ||
      TimelineEventType.milestone => true,
      _ => false,
    };

String _latestAdditionTitle(TimelineEventEntity event) {
  final String title = event.title.trim();
  if (!title.toLowerCase().endsWith('added')) return title;
  final String detail = event.detail.trim();
  final int marker = detail.toLowerCase().indexOf(' added ');
  return marker > 0 ? detail.substring(0, marker).trim() : title;
}

String _latestAdditionDetail(TimelineEventEntity event) {
  final String title = event.title.trim();
  return title.toLowerCase().endsWith('added')
      ? '$title in Timeline.'
      : event.detail.trim();
}

TaskEntity? _selectCurrentTask(List<TaskEntity> tasks, TimeBlock? nextBlock) {
  if (nextBlock != null) {
    for (final TaskEntity task in tasks) {
      if (task.id == nextBlock.taskId) return task;
    }
  }
  final List<TaskEntity> active = tasks
      .where((TaskEntity task) => !task.isCompleted && !task.isCanceled)
      .toList(growable: false);
  if (active.isEmpty) return null;
  active.sort((TaskEntity first, TaskEntity second) {
    final DateTime? firstSchedule = first.scheduledFor;
    final DateTime? secondSchedule = second.scheduledFor;
    if (firstSchedule != null && secondSchedule != null) {
      return firstSchedule.compareTo(secondSchedule);
    }
    if (firstSchedule != null) return -1;
    if (secondSchedule != null) return 1;
    return second.priority.compareTo(first.priority);
  });
  return active.first;
}

GoalEntity? _selectCurrentGoal(
  List<GoalEntity> goals,
  TaskEntity? currentTask,
) {
  final String? goalId = currentTask?.goalId;
  if (goalId != null) {
    for (final GoalEntity goal in goals) {
      if (goal.id == goalId) return goal;
    }
  }
  if (goals.isEmpty) return null;
  final List<GoalEntity> ordered = List<GoalEntity>.of(goals)
    ..sort((GoalEntity first, GoalEntity second) {
      final DateTime? firstTarget = first.targetDate;
      final DateTime? secondTarget = second.targetDate;
      if (firstTarget != null && secondTarget != null) {
        return firstTarget.compareTo(secondTarget);
      }
      if (firstTarget != null) return -1;
      if (secondTarget != null) return 1;
      return second.createdAt.compareTo(first.createdAt);
    });
  return ordered.first;
}

NoteEntity? _selectCurrentNote(
  List<NoteEntity> notes,
  TaskEntity? currentTask,
  GoalEntity? currentGoal,
) {
  final List<NoteEntity> active = notes
      .where((NoteEntity note) => !note.isArchived)
      .toList(growable: false);
  if (active.isEmpty) return null;
  active.sort(
    (NoteEntity first, NoteEntity second) =>
        second.updatedAt.compareTo(first.updatedAt),
  );
  for (final NoteEntity note in active) {
    if ((currentTask != null && note.taskId == currentTask.id) ||
        (currentGoal != null && note.goalId == currentGoal.id)) {
      return note;
    }
  }
  return active.first;
}

String _goalDetail(GoalEntity goal) {
  if (goal.targetDate != null) {
    return 'Target ${_formatDate(goal.targetDate!)}';
  }
  final String? description = goal.description?.trim();
  return description?.isNotEmpty == true ? description! : 'Active goal';
}

String _taskDetail(TaskEntity task) {
  final DateTime? scheduled = task.scheduledFor;
  if (scheduled != null) return _formatDateTime(scheduled);
  return 'Priority ${task.priority} · not scheduled';
}

String _noteDetail(NoteEntity note) {
  final String? body = note.body?.trim();
  if (body?.isNotEmpty == true) return body!;
  return 'Updated ${_formatDate(note.updatedAt)}';
}

Color _statusAccent(NexusDecisionStatus status) => switch (status) {
  NexusDecisionStatus.ready => AppColors.neonCyan,
  NexusDecisionStatus.partial ||
  NexusDecisionStatus.offline => AppColors.memoryAmber,
  NexusDecisionStatus.loading => AppColors.neonViolet,
  NexusDecisionStatus.error => AppColors.recallRed,
};

String _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _cleanTrajectoryCopy(String value) {
  return value.replaceFirst(RegExp(r'^SI (STATUS|ALERT):\s*'), '').trim();
}

String _titleCase(String value) {
  if (value.isEmpty) return 'Current';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _formatDate(DateTime value) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}

String _formatTime(DateTime value) {
  final int displayHour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$displayHour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _formatDateTime(DateTime value) {
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(value.year, value.month, value.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int difference = day.difference(today).inDays;
  final String date = switch (difference) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => _formatDate(value),
  };
  return '$date · ${_formatTime(value)}';
}
