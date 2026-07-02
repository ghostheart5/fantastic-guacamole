import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/features/insights/models/insight_model.dart';
import 'package:fantastic_guacamole/features/insights/state/insights_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/completion_insight_view.dart';
import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

class InsightScreen extends ConsumerStatefulWidget {
  const InsightScreen({super.key});

  @override
  ConsumerState<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends ConsumerState<InsightScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _levelUpAnim;
  bool _levelUpShown = false;

  @override
  void initState() {
    super.initState();
    _levelUpAnim = AnimationController(vsync: this);
    _levelUpAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        ref.read(profileProvider.notifier).clearLeveledUp();
        setState(() => _levelUpShown = true);
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
    final CompletionInsightView? completionInsight = ref.watch(completionInsightProvider);
    final SessionScoreView? score = ref.watch(sessionScoreProvider);
    final pattern = ref.watch(patternInsightProvider);
    final bool showLevelUp = profile.leveledUp && !_levelUpShown;

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/insigh_bg.png',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SmartPressable(
                          onTap: () {
                            ref.read(focusControllerProvider.notifier).reset();
                            ref.read(sessionScoreProvider.notifier).set(null);
                            ref.read(appFlowProvider.notifier).toCoach();
                          },
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [AppColors.neonCyan, AppColors.neonViolet],
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
                  const SizedBox(height: 20),
                  if (completionInsight != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _CompletionInsightPanel(insight: completionInsight),
                    ),
                  if (score != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _ScorePanel(score: score),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: pattern.when(
                      data: (text) => _PatternInsightPanel(text: text),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => const Text('Error'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _SystemHealthPanel(
                      summary: insightsBundle.summary,
                      healthScore: insightsBundle.healthScore,
                    ),
                  ),
                  Expanded(
                    child: insights.isEmpty
                        ? const Center(
                            child: Text(
                              'No insights yet',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: insights.length,
                            separatorBuilder: (context, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _InsightCard(insight: insights[index]),
                          ),
                  ),
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
          Text(summary, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: healthScore,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonViolet),
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
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5)),
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
              _StatChip(label: 'XP', value: '+${score.xp}', color: AppColors.memoryAmber),
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
  const _StatChip({required this.label, required this.value, required this.color});
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
            style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w800),
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
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.35)),
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
            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            insight.observation,
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
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
            style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
