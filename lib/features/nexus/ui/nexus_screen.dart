import 'dart:math' as math;

import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NexusScreen extends ConsumerStatefulWidget {
  const NexusScreen({super.key});

  @override
  ConsumerState<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends ConsumerState<NexusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState profile = ref.watch(profileProvider);
    final FocusState focus = ref.watch(focusControllerProvider);
    final double energy = ref.watch(energyProvider);
    final SIState siState = ref.watch(siStateProvider);

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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _SystemRings(
                      energy: energy,
                      fatigue: siState.fatigue,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _RingLabels(energy: energy, fatigue: siState.fatigue),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _StatStrip(profile: profile, siState: siState),
                ),
              ),
              if (focus.active)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ActiveSessionBanner(focus: focus),
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 32),
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _NexusHeader extends StatelessWidget {
  const _NexusHeader({required this.profile});
  final ProfileState profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
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
                SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ADAPTIVE INTELLIGENCE SYSTEM',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2.4,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [
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
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
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
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
// System rings
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
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(190, 190),
            painter: _RingPainter(
              energy: energy,
              fatigue: fatigue,
              pulse: pulse,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF62E0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(b),
                child: Text(
                  '${(energy * 100).round()}',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w100,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const Text(
                'ENERGY %',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 3,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ],
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

  static const double _outerR = 82.0;
  static const double _innerR = 56.0;
  static const double _stroke = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);

    _drawTicks(canvas, c);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
// Stat strip
// ---------------------------------------------------------------------------

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.profile, required this.siState});
  final ProfileState profile;
  final SIState siState;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 104,
          child: _StatChip(
            label: 'LVL',
            value: '${profile.level}',
            color: AppColors.neonCyan,
          ),
        ),
        SizedBox(
          width: 104,
          child: _StatChip(
            label: 'XP',
            value: '${profile.xp}',
            color: AppColors.pulseNeonBlue,
          ),
        ),
        SizedBox(
          width: 104,
          child: _StatChip(
            label: 'STREAK',
            value: '${profile.streak}d',
            color: AppColors.memoryAmber,
          ),
        ),
        SizedBox(
          width: 104,
          child: _StatChip(
            label: 'TODAY',
            value: '${siState.completedToday}',
            color: AppColors.neonViolet,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 2,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active session banner
// ---------------------------------------------------------------------------

class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner({required this.focus});
  final FocusState focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String elapsed =
        '${(focus.seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(focus.seconds % 60).toString().padLeft(2, '0')}';

    return SmartPressable(
      onTap: () => ref.read(appFlowProvider.notifier).toFocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Icon(
              Icons.radio_button_checked,
              color: AppColors.neonCyan,
              size: 14,
            ),
            const Text(
              'SESSION ACTIVE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.neonCyan,
              ),
            ),
            Text(
              elapsed,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neonCyan,
                letterSpacing: 2,
              ),
            ),
            const Text(
              'RESUME →',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action grid
// ---------------------------------------------------------------------------

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: HoloButton(
                label: 'Smart Coach',
                onTap: () => ref.read(appFlowProvider.notifier).toSmartCoach(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HoloButton(
                label: 'Start Focus',
                color: AppColors.neonViolet,
                onTap: () {
                  ref.read(focusControllerProvider.notifier).start();
                  ref.read(appFlowProvider.notifier).toFocus();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HoloButton(
                label: 'Day Plan',
                color: AppColors.memoryAmber,
                onTap: () => ref.read(appFlowProvider.notifier).toPlan(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HoloButton(
                label: 'Creator',
                color: AppColors.neonCyan,
                onTap: () => ref.read(appFlowProvider.notifier).toCreator(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        HoloButton(
          label: 'SI Console',
          onTap: () => ref.read(appFlowProvider.notifier).toConsole(),
        ),
      ],
    );
  }
}
