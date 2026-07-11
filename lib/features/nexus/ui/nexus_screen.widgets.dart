part of 'nexus_screen.dart';

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _NexusHeader extends ConsumerWidget {
  const _NexusHeader({required this.profile});
  final ProfileState profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationsProvider);
    final routes = ref.watch(routeSurfaceProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 390;
        final bool ultraCompact = constraints.maxWidth < 340;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            ultraCompact ? 12 : 20,
            16,
            ultraCompact ? 12 : 20,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartPressable(
                onTap: () => context.push(routes.notifications),
                child: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.neonCyan,
                    size: ultraCompact ? 20 : (compact ? 22 : 24),
                  ),
                ),
              ),
              SizedBox(width: ultraCompact ? 6 : (compact ? 8 : 12)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.iconNexus,
                      width: ultraCompact ? 18 : (compact ? 20 : 22),
                      height: ultraCompact ? 18 : (compact ? 20 : 22),
                      colorFilter: const ColorFilter.mode(
                        AppColors.neonCyan,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(height: ultraCompact ? 3 : 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'NEXUS',
                        style: TextStyle(
                          fontSize: ultraCompact ? 25 : (compact ? 29 : 32),
                          fontWeight: FontWeight.w900,
                          letterSpacing: ultraCompact
                              ? 3.2
                              : (compact ? 4.8 : 6),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ADAPTIVE LOGIC CORE',
                        style: TextStyle(
                          fontSize: ultraCompact ? 7 : (compact ? 8 : 9),
                          letterSpacing: ultraCompact
                              ? 1.3
                              : (compact ? 2.0 : 2.4),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: ultraCompact ? 2 : (compact ? 4 : 8)),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ultraCompact ? 72 : (compact ? 86 : 102),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulseDot(color: Colors.greenAccent),
                        SizedBox(width: ultraCompact ? 4 : 6),
                        Text(
                          'ONLINE',
                          style: TextStyle(
                            fontSize: ultraCompact ? 7 : (compact ? 8 : 9),
                            letterSpacing: ultraCompact
                                ? 0.8
                                : (compact ? 1.4 : 2),
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'LVL ${profile.level}  ·  ${profile.streak}d',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ultraCompact ? 8 : (compact ? 9 : 10),
                        color: Colors.white38,
                        letterSpacing: ultraCompact ? 0.3 : 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3 + _c.value * 0.5),
              blurRadius: 4 + _c.value * 8,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rings
// ---------------------------------------------------------------------------

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
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.neonViolet.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(210, 210),
                painter: _RingPainter(
                  energy: energy,
                  fatigue: fatigue,
                  pulse: pulse,
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonCyan.withValues(alpha: 0.28 + pulse * 0.12),
                      const Color(0xFF061624),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonCyan.withValues(alpha: 0.26),
                      blurRadius: 16,
                    ),
                    BoxShadow(
                      color: AppColors.neonViolet.withValues(alpha: 0.16),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$energyPct%',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'CLARITY $clarityPct%',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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

  static const double _outerR = 74.0;
  static const double _innerR = 50.0;
  static const double _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);

    _drawTicks(canvas, c);
    _drawAura(canvas, c);
    _drawRing(
      canvas,
      c,
      _outerR,
      energy,
      const Color(0xFF00E5FF),
      reversed: false,
    );
    _drawRing(
      canvas,
      c,
      _innerR,
      1 - fatigue,
      const Color(0xFF9B8AFB),
      reversed: false,
    );

    // Center glow
    canvas.drawCircle(
      c,
      5,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35 + pulse * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + pulse * 6),
    );
    canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFF00E5FF));
  }

  void _drawAura(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      _outerR + 24,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.04 + pulse * 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      c,
      _innerR + 20,
      Paint()
        ..color = const Color(0xFF9B8AFB).withValues(alpha: 0.04 + pulse * 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _drawTicks(Canvas canvas, Offset c) {
    final Paint tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int i = 0; i < 24; i++) {
      final double a = (i / 24) * 2 * math.pi - math.pi / 2;
      final double r1 = _outerR + 10;
      final double r2 = _outerR + (i % 6 == 0 ? 20 : 14);
      canvas.drawLine(
        c + Offset(math.cos(a) * r1, math.sin(a) * r1),
        c + Offset(math.cos(a) * r2, math.sin(a) * r2),
        tick,
      );
    }
  }

  void _drawRing(
    Canvas canvas,
    Offset c,
    double r,
    double value,
    Color color, {
    required bool reversed,
  }) {
    // Dim track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );

    if (value <= 0) return;

    final double sweep = value * 2 * math.pi * 0.88;
    final double start = -math.pi / 2;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    // Glow bloom
    canvas.drawArc(
      rect,
      start,
      reversed ? -sweep : sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.18 + pulse * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke + 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main arc
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

    // Endpoint glowing dot
    final double endA = start + (reversed ? -sweep : sweep);
    final Offset dot = c + Offset(r * math.cos(endA), r * math.sin(endA));
    canvas.drawCircle(
      dot,
      8,
      Paint()
        ..color = color.withValues(alpha: 0.4 + pulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(dot, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.energy != energy || old.fatigue != fatigue || old.pulse != pulse;
}

// ---------------------------------------------------------------------------
// Ring labels
// ---------------------------------------------------------------------------

class _RingLabels extends StatelessWidget {
  const _RingLabels({required this.energy, required this.fatigue});
  final double energy;
  final double fatigue;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool ultraCompact = width < 340;

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

class _NexusBridgeCard extends StatelessWidget {
  const _NexusBridgeCard({
    required this.profile,
    required this.energy,
    required this.completedToday,
  });

  final ProfileState profile;
  final double energy;
  final int completedToday;

  @override
  Widget build(BuildContext context) {
    final bool ultraCompact = MediaQuery.sizeOf(context).width < 340;

    final String greeting = energy >= 0.65
        ? 'High-capacity window active. Start one high-impact step now.'
        : energy >= 0.4
        ? 'Stable state online. Build momentum with one clear step.'
        : 'Low reserve detected. Start with one light win to restore rhythm.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        ultraCompact ? 10 : 12,
        ultraCompact ? 8 : 10,
        ultraCompact ? 10 : 12,
        ultraCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WELCOME BACK, ${profile.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            greeting,
            style: TextStyle(
              color: Colors.white70,
              fontSize: ultraCompact ? 11 : 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'LVL ${profile.level}  ·  STREAK ${profile.streak}d  ·  TODAY $completedToday',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white54,
              fontSize: ultraCompact ? 9 : 10,
              letterSpacing: ultraCompact ? 0.8 : 1.2,
            ),
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
                fontSize: 8,
                letterSpacing: 2,
                color: Colors.white38,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
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

// ---------------------------------------------------------------------------
// Dependency mesh
// ---------------------------------------------------------------------------

class _CoreSignalsStrip extends StatelessWidget {
  const _CoreSignalsStrip({
    required this.growthTitle,
    required this.narrativeSummary,
    required this.consistencySignal,
    required this.loadSignal,
    required this.soulContinuityPct,
    required this.narrativePresencePct,
  });

  final String growthTitle;
  final String narrativeSummary;
  final String consistencySignal;
  final String loadSignal;
  final int soulContinuityPct;
  final int narrativePresencePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonViolet.withValues(alpha: 0.14),
            AppColors.neonCyan.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SYSTEM SYNTHESIS (CROSS-MODULE)',
                  style: TextStyle(
                    color: AppColors.neonViolet,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SvgPicture.asset(
                AppAssets.iconInsights,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.neonViolet,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 6),
              SvgPicture.asset(
                AppAssets.iconReflect,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.neonCyan,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  growthTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SvgPicture.asset(
                AppAssets.iconFocus,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.82),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            narrativeSummary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SignalPill(label: 'Consistency', value: consistencySignal),
              _SignalPill(label: 'Load', value: loadSignal),
              _SignalPill(
                label: 'Soul Continuity',
                value: '$soulContinuityPct%',
              ),
              _SignalPill(label: 'Narrative', value: '$narrativePresencePct%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DependencyMesh extends ConsumerWidget {
  const _DependencyMesh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(nexusScreenModelProvider);
    final progression = ref.watch(progressionProvider);
    final model = modelAsync.asData?.value;
    final aggregation = model?.aggregation;
    final decision = model?.decision;
    final List<Task> tasks = aggregation?.tasks ?? const <Task>[];
    final List<GoalEntity> goals = aggregation?.goals ?? const <GoalEntity>[];
    final List<MemoryEntity> memories =
        aggregation?.memories ?? const <MemoryEntity>[];
    final List<FlowmapNode> flowNodesData =
        aggregation?.flowmapNodes ?? const <FlowmapNode>[];

    final int pendingTasks = tasks.length;
    final String nextTaskTitle = aggregation == null
        ? 'Loading task queue...'
        : (tasks.isEmpty ? 'Queue clear' : tasks.first.title);
    final int linkedTasks = tasks
        .where((Task task) => task.goalId != null && task.goalId!.isNotEmpty)
        .length;

    final List<String> goalTitles = goals
        .map((GoalEntity goal) => goal.title.trim())
        .where((String title) => title.isNotEmpty)
        .toList(growable: false);
    final String goalHeadline = goalTitles.isEmpty
        ? 'No active goals'
        : goalTitles.firstWhere(
            (String title) =>
                title.toLowerCase() != nextTaskTitle.toLowerCase(),
            orElse: () => 'Goal linked to "$nextTaskTitle"',
          );
    final int goalsWithTarget = goals
        .where((GoalEntity goal) => goal.targetDate != null)
        .length;

    final insights = aggregation?.insights;
    final String insightsHeadline = (insights == null || insights.items.isEmpty)
        ? 'No insight bundle published'
        : insights.items.first.title;

    final int recentMemories = memories
        .where((MemoryEntity memory) => memory.isRecent)
        .length;
    final String memoryHeadline = memories.isEmpty
        ? 'No recent memory capture'
        : memories.first.text;

    final int flowNodes = flowNodesData.length;
    final int connectedNodes = flowNodesData
        .where((FlowmapNode node) => node.connectedTo.isNotEmpty)
        .length;
    final List<String> flowTitles = flowNodesData
        .map((FlowmapNode node) => node.title.trim())
        .where((String title) => title.isNotEmpty)
        .toList(growable: false);
    final String flowHeadline = flowTitles.isEmpty
        ? 'No mapped threads'
        : flowTitles.firstWhere((String title) {
            final String lowered = title.toLowerCase();
            return lowered != nextTaskTitle.toLowerCase() &&
                lowered != goalHeadline.toLowerCase();
          }, orElse: () => 'Flow linked to "$nextTaskTitle"');
    final String syncStatus = modelAsync.isLoading
        ? 'SYNCING'
        : (modelAsync.hasError ? 'DEGRADED' : 'LIVE');
    final DateTime now = DateTime.now();
    final String syncTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final progress = progression.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NexusSyncStrip(status: syncStatus, timestamp: syncTime),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'NEXUS DEPENDENCY MESH (HOW MODULES CONNECT)',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DependencyCard(
              label: 'Coach',
              accent: AppColors.neonCyan,
              emphasize: true,
              value: modelAsync.isLoading
                  ? 'Syncing'
                  : (decision?.coachMessage.trim().isNotEmpty ?? false)
                  ? 'Live'
                  : 'Idle',
              headline:
                  decision?.coachMessage ?? 'No active coaching advice yet.',
              detail: (decision?.nextAction.trim().isNotEmpty ?? false)
                  ? 'Next action: ${decision!.nextAction}'
                  : 'SI engine advice routed into Nexus.',
            ),
            _DependencyCard(
              label: 'Progression',
              accent: const Color(0xFFFFD166),
              value: 'LVL ${progress.level}',
              headline: progress.levelTitle,
              detail: '${progress.xp} XP · ${progress.streak}d streak.',
            ),
            _DependencyCard(
              label: 'Tasks',
              accent: AppColors.memoryAmber,
              value: '$pendingTasks queued',
              headline: nextTaskTitle,
              detail: '$linkedTasks linked to goals.',
            ),
            _DependencyCard(
              label: 'Goals',
              accent: const Color(0xFF7AF7C4),
              value: '${goals.length} active',
              headline: goalHeadline,
              detail: '$goalsWithTarget with target dates.',
            ),
            _DependencyCard(
              label: 'Insights',
              accent: AppColors.neonViolet,
              value: '${insights?.items.length ?? 0} signals',
              headline: insightsHeadline,
              detail:
                  'Health ${(((insights?.healthScore ?? 0) * 100).round())}%.',
            ),
            _DependencyCard(
              label: 'Flowmap',
              accent: const Color(0xFF4BE6B0),
              value: '$flowNodes nodes',
              headline: flowHeadline,
              detail:
                  '$connectedNodes/$flowNodes connected decision nodes (node = a mapped task, goal, or idea link).',
            ),
            _DependencyCard(
              label: 'Memories',
              accent: const Color(0xFFFFB86B),
              value: '${memories.length} stored',
              headline: _truncate(memoryHeadline),
              detail: '$recentMemories recent memory traces.',
            ),
          ],
        ),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NexusSyncStrip extends StatelessWidget {
  const _NexusSyncStrip({required this.status, required this.timestamp});

  final String status;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final bool degraded = status == 'DEGRADED';
    final Color accent = degraded ? AppColors.recallRed : AppColors.neonCyan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'NEXUS CORE SYNC: $status',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Text(
            timestamp,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DependencyCard extends StatelessWidget {
  const _DependencyCard({
    required this.label,
    required this.value,
    required this.headline,
    required this.detail,
    required this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String headline;
  final String detail;
  final Color accent;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double contentWidth = width - 32;
    final int columns = width >= 1120
        ? 3
        : width >= 640
        ? 2
        : 1;
    final double cardWidth = emphasize || columns == 1
        ? contentWidth
        : columns == 3
        ? (contentWidth - 24) / 3
        : (contentWidth - 12) / 2;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(emphasize ? 13 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: emphasize ? 0.28 : 0.24),
        border: Border.all(
          color: accent.withValues(alpha: emphasize ? 0.34 : 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: emphasize ? 0.14 : 0.10),
            blurRadius: emphasize ? 20 : 16,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            maxLines: emphasize ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: emphasize ? 15 : 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _truncate(String text, {int max = 52}) {
  final String normalized = text.trim();
  if (normalized.length <= max) {
    return normalized;
  }
  return '${normalized.substring(0, max - 1)}...';
}

// ---------------------------------------------------------------------------
// Action grid
// ---------------------------------------------------------------------------

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < 360;
    final bool ultraCompact = width < 340;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        ultraCompact ? 10 : 12,
        ultraCompact ? 9 : 10,
        ultraCompact ? 10 : 12,
        ultraCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonCyan.withValues(alpha: 0.10),
            AppColors.neonViolet.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NEXUS ACTION HUB',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: AppColors.neonCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ultraCompact ? 10 : 12),
          if (compact) ...[
            HoloButton(
              label: 'Smart Coach',
              onTap: () => ref.read(appFlowProvider.notifier).toSmartCoach(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'Plan View',
              color: AppColors.memoryAmber,
              onTap: () => ref.read(appFlowProvider.notifier).toPlan(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'Create Task',
              color: AppColors.memoryAmber,
              onTap: () => ref.read(appFlowProvider.notifier).toCreator(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'Insights',
              color: AppColors.neonViolet,
              onTap: () => ref.read(appFlowProvider.notifier).toInsight(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'Flowmap',
              onTap: () => ref.read(appFlowProvider.notifier).toFlowmap(),
            ),
            const SizedBox(height: 10),
            HoloButton(
              label: 'SI Console',
              onTap: () => ref.read(appFlowProvider.notifier).toConsole(),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'Smart Coach',
                    onTap: () =>
                        ref.read(appFlowProvider.notifier).toSmartCoach(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoloButton(
                    label: 'Plan View',
                    color: AppColors.memoryAmber,
                    onTap: () => ref.read(appFlowProvider.notifier).toPlan(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'Create Task',
                    color: AppColors.memoryAmber,
                    onTap: () => ref.read(appFlowProvider.notifier).toCreator(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoloButton(
                    label: 'Insights',
                    color: AppColors.neonViolet,
                    onTap: () => ref.read(appFlowProvider.notifier).toInsight(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HoloButton(
                    label: 'Flowmap',
                    onTap: () => ref.read(appFlowProvider.notifier).toFlowmap(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoloButton(
                    label: 'SI Console',
                    onTap: () => ref.read(appFlowProvider.notifier).toConsole(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
