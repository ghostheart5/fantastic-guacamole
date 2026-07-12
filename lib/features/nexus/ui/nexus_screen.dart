import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
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

part 'nexus_screen.widgets.dart';

class NexusScreen extends ConsumerStatefulWidget {
  const NexusScreen({super.key});

  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState profile = ref.watch(profileProvider);
    final siState = ref.watch(siStateProvider);
    final double energy = siState.energy;
    final double fatigue = siState.fatigue;
    final int completedToday = siState.completedToday;
    final trajectory = ref.watch(trajectorySummaryProvider);
    final double momentum = trajectory.momentum;
    final int completedTasks = trajectory.completedTasks;

    final String consistencySignal = momentum >= 0.65
        ? 'High'
        : momentum >= 0.4
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
        : 'Growth Engine Priming';
    final String narrativeSummary = completedTasks > 0
        ? 'Momentum is active. Keep the next action small and immediate.'
        : 'No completed actions yet. Start with one clear task to establish narrative continuity.';
    final int soulContinuityPct =
        ((((1 - fatigue) * 0.55) + (momentum * 0.45)).clamp(0.0, 1.0) * 100).round();
    final double narrativePresence =
        ((completedTasks > 0 ? 0.5 : 0.28) + (profile.streak.clamp(0, 14) / 14) * 0.5).clamp(
          0.0,
          1.0,
        );
    final int narrativePresencePct = (narrativePresence * 100).round();

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/nexus_bg.jpg',
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
                    builder: (context, _) =>
                        _SystemRings(energy: energy, fatigue: fatigue, pulse: _pulse.value),
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
                  child: _CoreSignalsStrip(
                    growthTitle: growthTitle,
                    narrativeSummary: narrativeSummary,
                    consistencySignal: consistencySignal,
                    loadSignal: loadSignal,
                    soulContinuityPct: soulContinuityPct,
                    narrativePresencePct: narrativePresencePct,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _DependencyMesh(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 24), child: _ActionGrid()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
