import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';

part 'nexus_screen.widgets.dart';

class NexusScreen extends ConsumerStatefulWidget {
  const NexusScreen({super.key});

  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _showDeferredIntel = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Keep first paint fast by mounting heavyweight SI sections after frame one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showDeferredIntel = true;
      });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NexusStartupSummary startup = ref.watch(nexusStartupSummaryProvider);
    final ProfileState profile = startup.profile;
    final double energy = startup.energy;
    final double fatigue = startup.fatigue;
    final int completedToday = startup.completedToday;

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgNexus,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _NexusHeader(profile: profile)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _SystemRings(
                      energy: energy,
                      fatigue: fatigue,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _RingLabels(energy: energy, fatigue: fatigue),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _NexusBridgeCard(
                    profile: profile,
                    energy: energy,
                    completedToday: completedToday,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _showDeferredIntel
                      ? const _DeferredIntelligenceSection()
                      : _DeferredIntelligenceBootCard(startup: startup),
                ),
              ),
              if (_showDeferredIntel)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _DependencyMesh(),
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _DeferredDependencyBootCard(),
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: _ActionGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeferredIntelligenceBootCard extends StatelessWidget {
  const _DeferredIntelligenceBootCard({required this.startup});

  final NexusStartupSummary startup;

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planning overview',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            startup.startupDirective,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Emotional signal: ${startup.emotionLabel.toUpperCase()}  |  Energy ${(startup.energy * 100).round()}%',
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

class _DeferredDependencyBootCard extends StatelessWidget {
  const _DeferredDependencyBootCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        color: Colors.black.withValues(alpha: 0.22),
      ),
      child: const Text(
        'Loading your planning signals.',
        style: TextStyle(color: Colors.white60, fontSize: 11),
      ),
    );
  }
}

class _DeferredIntelligenceSection extends ConsumerWidget {
  const _DeferredIntelligenceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final siState = ref.watch(siStateProvider);
    final trajectory = ref.watch(trajectorySummaryProvider);
    final momentum = ref.watch(momentumEngineProvider);

    final double fatigue = siState.fatigue;
    final double trajectoryMomentum = trajectory.momentum;
    final int completedTasks = trajectory.completedTasks;

    final String consistencySignal = momentum.score >= 70
        ? 'High'
        : momentum.score >= 45
        ? 'Medium'
        : 'Low';
    final String loadSignal = fatigue >= 0.75
        ? 'Heavy'
        : fatigue >= 0.45
        ? 'Moderate'
        : 'Light';
    final String growthTitle = profile.streak >= 21
        ? 'Compounding Momentum'
        : profile.streak >= 7
        ? 'Stable Growth Arc'
        : completedTasks > 0
        ? 'Early Growth Signal'
        : 'Progress starting';
    final String narrativeSummary = completedTasks > 0
        ? 'Momentum is active. Keep the next action small and immediate.'
        : 'No completed actions yet. Start with one clear task to establish planning consistency.';
    final int soulContinuityPct =
        ((((1 - fatigue) * 0.55) + (trajectoryMomentum * 0.45)).clamp(
                  0.0,
                  1.0,
                ) *
                100)
            .round();
    final double narrativePresence =
        ((completedTasks > 0 ? 0.5 : 0.28) +
                (profile.streak.clamp(0, 14) / 14) * 0.5)
            .clamp(0.0, 1.0);
    final int narrativePresencePct = (narrativePresence * 100).round();

    return Column(
      children: [
        _CoreSignalsStrip(
          growthTitle: growthTitle,
          narrativeSummary: narrativeSummary,
          consistencySignal: consistencySignal,
          loadSignal: loadSignal,
          soulContinuityPct: soulContinuityPct,
          narrativePresencePct: narrativePresencePct,
        ),
      ],
    );
  }
}
