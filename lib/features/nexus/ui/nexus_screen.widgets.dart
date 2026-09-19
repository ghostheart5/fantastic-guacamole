part of 'nexus_screen.dart';

class _NexusHeader extends ConsumerWidget {
  const _NexusHeader({required this.profile});

  final ProfileState profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = NexusCopy.of(context);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        copy.productName,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.nexusTitle,
                      style: const TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: AppSizes.fontXs,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.tagline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: AppSizes.fontBodyLg,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.logicCore,
                      style: const TextStyle(
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
                semanticLabel: copy.openNotifications,
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
                semanticLabel: copy.logOut,
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
              label: Text(copy.context),
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
            copy.profileStatus(profile.name, profile.level, profile.streak),
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
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(NexusCopy.of(context).logOutFailed)),
      );
    }
  }
}

class _DecisionLoopStrip extends StatelessWidget {
  const _DecisionLoopStrip({
    required this.onBuild,
    required this.onResolve,
    required this.onInterrogate,
    required this.onCompare,
    required this.onReview,
  });

  final VoidCallback onBuild;
  final VoidCallback onResolve;
  final VoidCallback onInterrogate;
  final VoidCallback onCompare;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final copy = NexusCopy.of(context);
    return _GlassPanel(
      accent: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.decisionLoop,
            style: const TextStyle(
              color: AppColors.neonViolet,
              fontSize: AppSizes.fontMicro,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.decisionLoopSubtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontBody,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _LoopAction(
                icon: Icons.add_task_rounded,
                label: copy.buildReality,
                onTap: onBuild,
              ),
              _LoopAction(
                icon: Icons.bolt_rounded,
                label: copy.resolveNow,
                onTap: onResolve,
              ),
              _LoopAction(
                icon: Icons.psychology_alt_outlined,
                label: copy.interrogate,
                onTap: onInterrogate,
              ),
              _LoopAction(
                icon: Icons.alt_route_rounded,
                label: copy.compareFutures,
                onTap: onCompare,
              ),
              _LoopAction(
                icon: Icons.fact_check_outlined,
                label: copy.reviewTruth,
                onTap: onReview,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            copy.builtForReality,
            style: const TextStyle(
              color: AppColors.memoryAmber,
              fontSize: AppSizes.fontMicro,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          ...copy.realLifeSituations.map(
            (String situation) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '›',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      situation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: AppSizes.fontCaption,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.memoryAmber,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  copy.loopControlNote,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: AppSizes.fontCaption,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopAction extends StatelessWidget {
  const _LoopAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 17, color: AppColors.neonCyan),
    label: Text(label),
    onPressed: onTap,
    backgroundColor: AppColors.bgSecondary.withValues(alpha: .78),
    side: BorderSide(color: AppColors.neonCyan.withValues(alpha: .24)),
    labelStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: AppSizes.fontCaption,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
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
    required this.momentumLabel,
    required this.hasObservedEnergy,
    required this.hasObservedClarity,
    required this.onEnergy,
    required this.onClarity,
    required this.onMomentum,
    required this.pulse,
  });

  final double energy;
  final double fatigue;
  final String momentumLabel;
  final bool hasObservedEnergy;
  final bool hasObservedClarity;
  final VoidCallback onEnergy;
  final VoidCallback onClarity;
  final VoidCallback onMomentum;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final copy = NexusCopy.of(context);
    return Semantics(
      container: true,
      label: copy.vitalsSummary(
        energyPercent: hasObservedEnergy ? (energy * 100).round() : null,
        clarityPercent: hasObservedClarity
            ? ((1 - fatigue) * 100).round()
            : null,
        momentumLabel: momentumLabel,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _VitalMetric(
              label: copy.energy,
              onTap: onEnergy,
              hint: copy.energyHint,
              value: hasObservedEnergy
                  ? '${(energy * 100).round()}%'
                  : copy.unmeasured,
              accent: AppColors.neonCyan,
              pulse: pulse,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _VitalMetric(
              label: copy.clarity,
              onTap: onClarity,
              hint: copy.clarityHint,
              value: hasObservedClarity
                  ? '${((1 - fatigue) * 100).round()}%'
                  : copy.unchecked,
              accent: AppColors.neonViolet,
              pulse: pulse,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _VitalMetric(
              label: copy.momentum,
              onTap: onMomentum,
              hint: copy.momentumHint,
              value: copy.momentumValue(momentumLabel),
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
    required this.onTap,
    required this.hint,
  });

  final String label;
  final String value;
  final Color accent;
  final double pulse;
  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: Semantics(
        button: true,
        hint: hint,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
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
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: accent.withValues(alpha: .84 + pulse * .16),
                        fontSize: AppSizes.fontBodyLg,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
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
    final copy = NexusCopy.of(context);
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
        _SectionHeading(
          eyebrow: copy.currentDecision,
          title: copy.nextMove,
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
    final copy = NexusCopy.of(context);
    final String title = _firstNonEmpty(<String?>[
      decision?.recommendedAction,
      block?.title,
      copy.buildNextStep,
    ]);
    final String rationale = _firstNonEmpty(<String?>[
      decision?.whyItMatters,
      decision?.rationale,
      block == null ? copy.addTaskReason : copy.scheduledReason,
    ]);
    final String? confidenceLabel = decision == null
        ? null
        : l10n.provisionalEvidenceConfidenceLabel(decision!.confidence);
    // A nearby block is not necessarily the displayed decision. Recovery and
    // reconciliation guidance must not expose another task's completion action.
    final bool showsTask =
        block != null &&
        (decision == null || decision!.subjectId == block!.taskId) &&
        (title == block!.title || title == 'Work on: ${block!.title}');
    // Translate the system prefix only after identity agreement; never parse
    // or translate a user-authored task title to authorize completion.
    final displayTitle = showsTask && title == 'Work on: ${block!.title}'
        ? copy.workOn(block!.title)
        : title;
    final displayRationale =
        decision?.personContextExplanations.isNotEmpty ?? false
        ? rationale
        : copy.systemRationale(rationale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StatusLabel(
              label: copy.decisionStatus(decisionModel.statusLabel),
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
          displayTitle,
          key: const Key('nexus-recommended-action'),
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
          displayRationale,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: AppSizes.fontBodyLg,
            height: 1.42,
          ),
        ),
        if (decision != null) ...<Widget>[
          const SizedBox(height: 14),
          _DecisionPacketRow(
            icon: Icons.sensors_rounded,
            label: copy.evidence,
            value: copy.evidenceSummary(
              evidenceCount: decision!.evidence.length,
              freshCount: decision!.evidence
                  .where(
                    (OperatingEvidence item) =>
                        item.isFreshAt(decision!.generatedAt),
                  )
                  .length,
              sourceCount: decision!.sourceRevisions.length,
            ),
            color: AppColors.neonCyan,
          ),
          const SizedBox(height: 9),
          _DecisionPacketRow(
            icon: Icons.blur_on_rounded,
            label: copy.uncertainty,
            value: copy.uncertaintySummary(
              assumptionCount: decision!.assumptions.length,
              warningCount: decision!.warnings.length,
              expired: decision!.isExpiredAt(DateTime.now()),
            ),
            color: AppColors.neonViolet,
          ),
          const SizedBox(height: 9),
          _DecisionPacketRow(
            icon: Icons.tune_rounded,
            label: copy.control,
            value: copy.controlSummary(
              requiresConfirmation: decision!.actionIntent.requiresConfirmation,
              reversible: decision!.actionIntent.reversible,
            ),
            color: AppColors.memoryAmber,
          ),
          if (decision!.consequenceOfDelay.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              copy.delayed(decision!.consequenceOfDelay),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: AppSizes.fontCaption,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
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
                  copy.whyChanged(
                    decision!.personContextExplanations.join(' '),
                  ),
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
                      child: Text(copy.ignoreContext),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (showsTask) ...<Widget>[
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
                  '${copy.dateTime(context, block!.start)}  →  ${copy.time(context, block!.end)}',
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
                label: Text(copy.reviewSuggestion),
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
            if (showsTask && !block!.completed) ...<Widget>[
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

class _DecisionPacketRow extends StatelessWidget {
  const _DecisionPacketRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppSizes.fontMicro,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppSizes.fontCaption,
              height: 1.35,
            ),
          ),
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
    final copy = NexusCopy.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            copy.suggestionUnavailable,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        IconButton(
          onPressed: onRetry,
          tooltip: copy.retry,
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
  final ValueChanged<TaskEntity?> onOpenTask;
  final ValueChanged<NoteEntity?> onOpenNote;

  @override
  Widget build(BuildContext context) {
    final copy = NexusCopy.of(context);
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
        _SectionHeading(
          eyebrow: copy.priorities,
          title: copy.prioritiesSubtitle,
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
                label: copy.goal,
                title: currentGoal?.title ?? copy.noGoal,
                detail: currentGoal == null
                    ? copy.createGoal
                    : _goalDetail(currentGoal, context),
                accent: AppColors.neonViolet,
                onTap: onOpenGoal,
              ),
              const _PanelDivider(),
              _FocusRow(
                icon: Icons.check_circle_outline_rounded,
                label: copy.task,
                title: currentTask?.title ?? nextBlock?.title ?? copy.noTask,
                detail: currentTask != null
                    ? _taskDetail(currentTask, context)
                    : nextBlock != null
                    ? copy.dateTime(context, nextBlock!.start)
                    : copy.createTask,
                accent: AppColors.neonCyan,
                onTap: () => onOpenTask(currentTask),
              ),
              const _PanelDivider(),
              _FocusRow(
                icon: Icons.sticky_note_2_outlined,
                label: copy.note,
                title: notes.isLoading
                    ? copy.loadingNote
                    : currentNote?.title ?? copy.noNote,
                detail: currentNote == null
                    ? copy.createNote
                    : _noteDetail(currentNote, context),
                accent: AppColors.memoryAmber,
                onTap: () => onOpenNote(currentNote),
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
      semanticLabel: NexusCopy.of(context).open(label),
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
