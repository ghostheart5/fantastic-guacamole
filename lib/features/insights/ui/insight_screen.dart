import 'dart:math' as math;

import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/completion_insight_view.dart';
import 'package:fantastic_guacamole/state/models/insight_model.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:fantastic_guacamole/state/providers/behavior_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

class InsightScreen extends ConsumerStatefulWidget {
  const InsightScreen({super.key});

  @override
  ConsumerState<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends ConsumerState<InsightScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _levelUpAnim;
  bool _levelUpShown = false;
  String? _lastPublishedInsightSignature;

  void _runAfterBuild(VoidCallback action) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      action();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  @override
  void initState() {
    super.initState();
    _levelUpAnim = AnimationController(vsync: this);
    _levelUpAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _runAfterBuild(() {
          ref.read(profileProvider.notifier).clearLeveledUp();
          setState(() => _levelUpShown = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _levelUpAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insightsBundle = ref.watch(insightsBundleProvider);
    final profile = ref.watch(profileProvider);
    final insights = insightsBundle.items;
    final CompletionInsightView? completionInsight = ref.watch(
      completionInsightProvider,
    );
    final SessionScoreView? score = ref.watch(sessionScoreProvider);
    final pattern = ref.watch(patternInsightProvider);
    final bool showLevelUp = profile.leveledUp && !_levelUpShown;
    final String publishSignature = _publishSignatureFor(
      insightsBundle: insightsBundle,
      patternState: pattern,
      completionInsight: completionInsight,
    );

    if (publishSignature.isNotEmpty &&
        publishSignature != _lastPublishedInsightSignature) {
      _lastPublishedInsightSignature = publishSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(insightsActionsProvider).publishBundle(insightsBundle);
      });
    }

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/insigh_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SmartPressable(
                            onTap: () {
                              ref.read(sessionScoreProvider.notifier).set(null);
                              ref.read(appFlowProvider.notifier).toCoach();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.3,
                                  ),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            AppColors.neonCyan,
                                            AppColors.neonViolet,
                                          ],
                                        ).createShader(bounds),
                                    child: const Text(
                                      'SYSTEM INSIGHTS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'SI STATE INTERPRETATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (completionInsight != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _CompletionInsightPanel(
                          insight: completionInsight,
                        ),
                      ),
                    ),
                  if (score != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _ScorePanel(score: score),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: pattern.when(
                        data: (text) => _PatternInsightPanel(text: text),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => const Text('Error'),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _SystemHealthPanel(
                        summary: insightsBundle.summary,
                        healthScore: insightsBundle.healthScore,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _WeeklyXpRow()),
                  const SliverToBoxAdapter(child: _BehaviorIdentityRow()),
                  if (insights.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Center(
                          child: Text(
                            'No insights yet',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final int contentIndex = index ~/ 2;
                          if (index.isOdd) {
                            return const SizedBox(height: 12);
                          }
                          return _InsightCard(insight: insights[contentIndex]);
                        }, childCount: insights.length * 2 - 1),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            if (showLevelUp)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Lottie.asset(
                      'assets/animations/level_up.json',
                      controller: _levelUpAnim,
                      onLoaded: (composition) {
                        _levelUpAnim.duration = composition.duration;
                        if (!_levelUpAnim.isAnimating) _levelUpAnim.forward();
                      },
                      width: 300,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _publishSignatureFor({
    required InsightsBundle insightsBundle,
    required AsyncValue<String> patternState,
    required CompletionInsightView? completionInsight,
  }) {
    final String pattern = patternState.maybeWhen(
      data: (String value) => value.trim(),
      orElse: () => '',
    );
    final String completion = completionInsight == null
        ? ''
        : '${completionInsight.summary}|${completionInsight.observation}|${completionInsight.suggestion}';
    final String items = insightsBundle.items
        .map((Insight item) => '${item.title}|${item.description}')
        .join('::');
    return '${insightsBundle.summary}|${insightsBundle.healthScore.toStringAsFixed(3)}|$completion|$pattern|$items';
  }
}

class _WeeklyXpRow extends ConsumerWidget {
  const _WeeklyXpRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final traj = ref.watch(trajectorySummaryProvider);
    final score = ref.watch(sessionScoreProvider);

    final double momentum = traj.momentum;
    final int streak = profile.streak;

    // Build 7-day estimated XP bars (most recent = index 6)
    final bars = List.generate(7, (i) {
      final double decay = math.pow(0.72, 6 - i).toDouble();
      final double streakBoost = (i >= 7 - streak.clamp(0, 7)) ? 1.1 : 1.0;
      final double momentumMod = momentum * 0.3 + 0.7;
      return (decay * streakBoost * momentumMod).clamp(0.05, 1.0);
    });
    final maxBar = bars.reduce((a, b) => a > b ? a : b);
    final normalised = bars.map((b) => b / maxBar).toList();

    // Quality sparkline: last 5 bars, rightmost = current
    final double curQ = score?.quality ?? 0.0;
    final qualBars = List.generate(5, (i) {
      if (i == 4) return curQ;
      final double decay = math.pow(0.8, 4 - i).toDouble();
      return (curQ *
              decay *
              (0.8 + math.Random(profile.xp + i).nextDouble() * 0.4))
          .clamp(0.0, 1.0);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: _NeonCard(
              label: 'WEEKLY XP',
              color: AppColors.memoryAmber,
              child: SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: _BarChartPainter(
                    bars: normalised,
                    color: AppColors.memoryAmber,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NeonCard(
              label: 'QUALITY',
              color: AppColors.neonCyan,
              child: SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: _BarChartPainter(
                    bars: qualBars,
                    color: AppColors.neonCyan,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BehaviorIdentityRow extends ConsumerWidget {
  const _BehaviorIdentityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behavior = ref.watch(behaviorStateProvider);
    final identity = ref.watch(identityStateProvider);
    final archetype = ref.watch(identityStateProvider.notifier).archetype;

    final consistencyPct = (behavior.consistency * 100).round();
    final capacityPct = (behavior.capacity * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _NeonCard(
              label: 'CONSISTENCY',
              color: AppColors.neonViolet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$consistencyPct%',
                        style: const TextStyle(
                          color: AppColors.neonViolet,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        consistencyPct >= 60
                            ? '▲'
                            : consistencyPct >= 35
                            ? '→'
                            : '▼',
                        style: TextStyle(
                          color: consistencyPct >= 60
                              ? Colors.greenAccent
                              : consistencyPct >= 35
                              ? AppColors.memoryAmber
                              : Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _MiniBar(
                    value: behavior.consistency,
                    color: AppColors.neonViolet,
                    label: 'Consistency',
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(
                    value: behavior.capacity,
                    color: AppColors.neonCyan,
                    label: 'Capacity $capacityPct%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NeonCard(
              label: 'ARCHETYPE',
              color: AppColors.neonCyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      archetype,
                      style: const TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MiniBar(
                    value: identity.disciplineIdentity,
                    color: AppColors.memoryAmber,
                    label: 'Discipline',
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(
                    value: identity.focusIdentity,
                    color: AppColors.neonCyan,
                    label: 'Focus',
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(
                    value: identity.growthIdentity,
                    color: AppColors.neonViolet,
                    label: 'Growth',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.value,
    required this.color,
    required this.label,
  });
  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonCard extends StatelessWidget {
  const _NeonCard({
    required this.label,
    required this.color,
    required this.child,
  });
  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071019),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.bars, required this.color});
  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final barW = (size.width - (bars.length - 1) * 3) / bars.length;
    for (int i = 0; i < bars.length; i++) {
      final x = i * (barW + 3);
      final h = size.height * bars[i];
      final isLast = i == bars.length - 1;
      final paint = Paint()
        ..color = isLast ? color : color.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, barW, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.bars != bars;
}

class _SystemHealthPanel extends StatelessWidget {
  const _SystemHealthPanel({required this.summary, required this.healthScore});

  final String summary;
  final double healthScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071019),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM HEALTH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neonViolet,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: healthScore,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.neonViolet,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternInsightPanel extends StatelessWidget {
  const _PatternInsightPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071019),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PATTERN INSIGHT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neonCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score});
  final SessionScoreView score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: 0.07),
            blurRadius: 16,
            spreadRadius: -2,
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
                  color: AppColors.neonViolet,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SESSION SCORE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonViolet,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                label: 'XP',
                value: '+${score.xp}',
                color: AppColors.memoryAmber,
              ),
              _StatChip(
                label: 'QUALITY',
                value: '${(score.quality * 100).toInt()}%',
                color: AppColors.neonCyan,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score.feedback,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.neonViolet.withValues(alpha: 0.85),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionInsightPanel extends StatelessWidget {
  const _CompletionInsightPanel({required this.insight});
  final CompletionInsightView insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -2,
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
                  color: AppColors.memoryAmber,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SESSION COMPLETE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.memoryAmber,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.summary,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.observation,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.suggestion,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.memoryAmber.withValues(alpha: 0.9),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
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
              const SizedBox(width: 10),
              Text(
                insight.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonCyan,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
