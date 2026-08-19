part of 'nexus_screen.dart';

class _NexusHeader extends ConsumerWidget {
  const _NexusHeader({required this.profile});

  final ProfileState profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationsProvider);
    final routes = ref.watch(routeSurfaceProvider);
    final double width = MediaQuery.sizeOf(context).width;
    final bool ultraCompact = width < Breakpoints.ultraCompact;
    final bool compact = width < Breakpoints.compact;
    final double statusFontSize = ultraCompact
        ? AppSizes.fontMicro
        : compact
        ? AppSizes.fontXs
        : AppSizes.fontSm;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ultraCompact ? 12 : 16,
        16,
        ultraCompact ? 12 : 16,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartPressable(
            onTap: () => context.push(routes.notifications),
            semanticLabel: 'Open notifications',
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.neonCyan,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppAssets.iconNexus,
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    AppColors.neonCyan,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 4),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'NEXUS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ADAPTIVE LOGIC CORE',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2.4,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.name.isEmpty
                      ? 'Today is ready when you are.'
                      : 'Welcome back, ${profile.name}.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'LVL ${profile.level}  |  STREAK ${profile.streak}d',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: statusFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SmartPressable(
            onTap: () => unawaited(_signOut(context, ref)),
            child: Tooltip(
              message: 'Log out',
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.neonViolet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.neonViolet.withValues(alpha: 0.38),
                  ),
                ),
                child: const Icon(
                  Icons.logout,
                  size: 18,
                  color: AppColors.neonViolet,
                ),
              ),
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
      if (context.mounted) {
        context.go(routes.login);
      }
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }
}

class _NexusTimeBlockSchedule extends StatelessWidget {
  const _NexusTimeBlockSchedule({
    required this.blocks,
    required this.nextBlockId,
    required this.decisionModel,
    required this.completingTaskIds,
    required this.onCompleteTask,
    required this.onRetry,
    required this.onCreateTask,
    required this.onOpenTimeline,
    required this.onReviewPlan,
  });

  final AsyncValue<List<TimeBlock>> blocks;
  final String? nextBlockId;
  final NexusDecisionModel decisionModel;
  final Set<String> completingTaskIds;
  final Future<void> Function(String taskId) onCompleteTask;
  final VoidCallback onRetry;
  final VoidCallback onCreateTask;
  final VoidCallback onOpenTimeline;
  final VoidCallback onReviewPlan;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final Color accent = _statusAccent(decisionModel.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonCyan.withValues(alpha: 0.12),
            AppColors.neonViolet.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.32),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScheduleHeader(
            status: decisionModel.statusLabel,
            detail: decisionModel.statusDetail,
            accent: accent,
            pendingSyncCount: decisionModel.pendingSyncCount,
            isOnline: decisionModel.isOnline,
          ),
          const SizedBox(height: 12),
          blocks.when(
            loading: () => _ScheduleLoading(accent: accent),
            error: (_, _) =>
                _ScheduleRecovery(onRetry: onRetry, accent: accent),
            data: (List<TimeBlock> value) {
              final List<TimeBlock> ordered = value
                  .where((TimeBlock block) => block.validate())
                  .toList(growable: false);
              if (ordered.isEmpty) {
                return _EmptySchedulePrompt(
                  onCreateTask: onCreateTask,
                  onOpenTimeline: onOpenTimeline,
                  accent: accent,
                );
              }

              return Column(
                children: [
                  for (final TimeBlock block in ordered) ...[
                    TimeBlockWidget(
                      taskId: block.taskId,
                      title: block.title,
                      start: _formatTime(block.start),
                      end: _formatTime(block.end),
                      accent: block.id == nextBlockId
                          ? AppColors.neonCyan
                          : AppColors.neonViolet,
                      completed: block.completed,
                      isNext: block.id == nextBlockId,
                      isCompleting: completingTaskIds.contains(block.taskId),
                      supportingText: block.id == nextBlockId
                          ? _supportingText(decisionModel)
                          : null,
                      onReviewPlan: block.id == nextBlockId
                          ? onReviewPlan
                          : null,
                      onCompleteTask: onCompleteTask,
                    ),
                    if (block != ordered.last) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          if (decisionModel.status == NexusDecisionStatus.error) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.text(ChronoSparkString.retryNexus)),
            ),
          ],
        ],
      ),
    );
  }

  static Color _statusAccent(NexusDecisionStatus status) => switch (status) {
    NexusDecisionStatus.ready => AppColors.neonCyan,
    NexusDecisionStatus.partial => AppColors.memoryAmber,
    NexusDecisionStatus.offline => AppColors.memoryAmber,
    NexusDecisionStatus.loading => AppColors.neonViolet,
    NexusDecisionStatus.error => AppColors.recallRed,
  };

  static String _formatTime(DateTime value) {
    final int hour = value.hour;
    final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final String minute = value.minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $period';
  }

  static String? _supportingText(NexusDecisionModel model) {
    final OperatingDecisionReceipt? decision = model.intelligence?.decision;
    if (decision == null) {
      return null;
    }
    final String reason = decision.whyItMatters.trim();
    final String rationale = decision.rationale.trim();
    if (reason.isEmpty) {
      return rationale.isEmpty ? null : rationale;
    }
    if (rationale.isEmpty || rationale == reason) {
      return reason;
    }
    return '$reason $rationale';
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.status,
    required this.detail,
    required this.accent,
    required this.pendingSyncCount,
    required this.isOnline,
  });

  final String status;
  final String detail;
  final Color accent;
  final int pendingSyncCount;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final String syncCopy = isOnline
        ? (pendingSyncCount == 0
              ? 'Synced locally'
              : '$pendingSyncCount queued')
        : 'Offline mode';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: accent,
                      fontSize: AppSizes.fontSm,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    syncCopy,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: AppSizes.fontBody,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleLoading extends StatelessWidget {
  const _ScheduleLoading({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Building today from the current plan.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _ScheduleRecovery extends StatelessWidget {
  const _ScheduleRecovery({required this.onRetry, required this.accent});

  final VoidCallback onRetry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today could not load from local planning evidence.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: Icon(Icons.refresh, color: accent),
          label: Text(l10n.text(ChronoSparkString.retryNexus)),
        ),
      ],
    );
  }
}

class _EmptySchedulePrompt extends StatelessWidget {
  const _EmptySchedulePrompt({
    required this.onCreateTask,
    required this.onOpenTimeline,
    required this.accent,
  });

  final VoidCallback onCreateTask;
  final VoidCallback onOpenTimeline;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No time blocks are scheduled for today.',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontLabelLg,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create one task or open Timeline to give Nexus something concrete to order.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: AppSizes.fontBody,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_task),
              label: const Text('Create task'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenTimeline,
              icon: Icon(Icons.timeline, color: accent),
              label: const Text('Open Timeline'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SystemRings extends StatelessWidget {
  const _SystemRings({
    required this.energy,
    required this.fatigue,
    required this.pulse,
  });

  final double energy;
  final double fatigue;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final int energyPct = (energy * 100).round();
    final int clarityPct = ((1 - fatigue) * 100).round();

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 210,
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: pulse * (math.pi / 10),
                child: Container(
                  width: 196,
                  height: 196,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -pulse * (math.pi / 8),
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.neonViolet.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(160, 160),
                painter: _RingPainter(
                  energy: energy,
                  fatigue: fatigue,
                  pulse: pulse,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$energyPct',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: .92,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ENERGY',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: AppSizes.fontMicro,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CLARITY $clarityPct%',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.energy,
    required this.fatigue,
    required this.pulse,
  });

  final double energy;
  final double fatigue;
  final double pulse;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect outer = Rect.fromCircle(center: center, radius: 70);
    final Rect inner = Rect.fromCircle(center: center, radius: 52);

    _drawArc(canvas, outer, energy.clamp(0, 1), AppColors.neonCyan, pulse);
    _drawArc(
      canvas,
      inner,
      (1 - fatigue).clamp(0, 1),
      AppColors.neonViolet,
      pulse,
      reversed: true,
    );
  }

  void _drawArc(
    Canvas canvas,
    Rect rect,
    double value,
    Color color,
    double pulse, {
    bool reversed = false,
  }) {
    final Offset center = rect.center;
    final double radius = rect.width / 2;
    final double start = -math.pi / 2 + (pulse * math.pi / 14);
    final double sweep = math.pi * 2 * value;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      start,
      reversed ? -sweep : sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );

    final double end = start + (reversed ? -sweep : sweep);
    final Offset dot =
        center + Offset(radius * math.cos(end), radius * math.sin(end));
    canvas.drawCircle(
      dot,
      7,
      Paint()
        ..color = color.withValues(alpha: 0.35 + pulse * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(dot, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.energy != energy ||
      oldDelegate.fatigue != fatigue ||
      oldDelegate.pulse != pulse;
}

class _RingLabels extends StatelessWidget {
  const _RingLabels({required this.energy, required this.fatigue});

  final double energy;
  final double fatigue;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool ultraCompact = width < Breakpoints.ultraCompact;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ultraCompact ? 18 : 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: ultraCompact ? 18 : 30,
        runSpacing: ultraCompact ? 6 : 8,
        children: [
          _RingLabel(
            label: 'ENERGY',
            value: '${(energy * 100).round()}%',
            color: AppColors.neonCyan,
          ),
          _RingLabel(
            label: 'CLARITY',
            value: '${((1 - fatigue) * 100).round()}%',
            color: AppColors.neonViolet,
          ),
        ],
      ),
    );
  }
}

class _RingLabel extends StatelessWidget {
  const _RingLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: AppSizes.fontMicro,
                letterSpacing: 2,
                color: Colors.white38,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: AppSizes.fontBodyLg,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
