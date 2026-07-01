import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../ui/layout/holo_background.dart';
import '../../../ui/widgets/chronospark_bottom_nav.dart';
import '../../../ui/widgets/neon_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fxController;

  @override
  void initState() {
    super.initState();
    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _fxController.dispose();
    super.dispose();
  }

  Widget _sparkTile(
    BuildContext context, {
    required String title,
    required String time,
    required Color edgeColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.panelGlassAlt,
        borderRadius: BorderRadius.circular(AppSizes.panelRadius),
        border: Border.all(
          color: edgeColor.withValues(alpha: 0.65),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: edgeColor.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Time: $time',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _gadgetIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.panelGlassAlt,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.panelBorder),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: AppColors.neonCyanAlt),
            const SizedBox(height: AppSizes.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String timeLabel =
        '${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      body: HoloBackground(
        backgroundAsset: 'assets/backgrounds/main_bg.png',
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: <Widget>[
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'CHRONOSPARK',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.neonCyanAlt,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      'Energy 78%  |  3 Missions  |  2 Events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'Focus Window: 9AM - 11AM',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SI INSIGHT HEADER',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    SizedBox(
                      height: 76,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _fxController,
                              builder: (BuildContext context, Widget? child) {
                                return CustomPaint(
                                  painter: _WaveformPainter(
                                    _fxController.value,
                                  ),
                                );
                              },
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Cognitive load stable.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.recallRed,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: AppSizes.xs),
                                Text(
                                  'Mission priority recalibrated.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PULSE BAR - EMOTION/ENERGY READOUT',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Stack(
                      children: <Widget>[
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.neonCyan,
                                AppColors.recallRed,
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _fxController,
                            builder: (BuildContext context, Widget? child) {
                              final double phase = _fxController.value;
                              return Stack(
                                children: <Widget>[
                                  Positioned(
                                    left: 24 + (phase * 32),
                                    top: 3,
                                    child: Container(
                                      width: 26,
                                      height: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 120 + (phase * 48),
                                    top: 8,
                                    child: Container(
                                      width: 16,
                                      height: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 220 + (phase * 20),
                                    top: 13,
                                    child: Container(
                                      width: 22,
                                      height: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.50,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    const Row(
                      children: <Widget>[
                        Expanded(child: Text('Energy: 72%')),
                        Text('Cognitive Strain: Low'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'TODAY\'S SPARKS - TOP 3 MISSIONS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    _sparkTile(
                      context,
                      title: 'Complete Tactical Routine Update',
                      time: '10:00 AM',
                      edgeColor: AppColors.recallRed,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    _sparkTile(
                      context,
                      title: 'Review ChronoLogs Archive',
                      time: '1:00 PM',
                      edgeColor: AppColors.neonCyan,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    _sparkTile(
                      context,
                      title: 'Prep Mission Sequence',
                      time: '4:00 PM',
                      edgeColor: AppColors.memoryAmber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'GADGETS BAR',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _gadgetIcon(
                            context,
                            icon: Icons.filter_center_focus,
                            label: 'Focus',
                            onTap: () =>
                                Navigator.pushNamed(context, '/gadget/focus'),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _gadgetIcon(
                            context,
                            icon: Icons.psychology_alt,
                            label: 'SI Insight',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/gadget/si-insight',
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _gadgetIcon(
                            context,
                            icon: Icons.hub,
                            label: 'Constellation',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/gadget/constellation',
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _gadgetIcon(
                            context,
                            icon: Icons.calendar_month,
                            label: 'ChronoGrid',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/gadget/chronogrid',
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _gadgetIcon(
                            context,
                            icon: Icons.warning_amber,
                            label: 'Fracture',
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/gadget/fracture-monitor',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),
              NeonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'TEMPORAL PREVIEW - MINI TIMELINE',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Container(
                              width: 2,
                              height: 22,
                              color: AppColors.neonCyan,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.neonCyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 26,
                              color: AppColors.neonCyan,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.recallRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 26,
                              color: AppColors.neonCyan,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.memoryAmber,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSizes.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Blue nodes = events'),
                              SizedBox(height: AppSizes.sm),
                              Text('Red nodes = high-priority missions'),
                              SizedBox(height: AppSizes.sm),
                              Text('Amber nodes = logs waiting review'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      'SI overlay: Predicted bottleneck at 3:00 PM',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.recallRed,
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
      bottomNavigationBar: const ChronoSparkBottomNav(selectedIndex: 0),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint cyan = Paint()
      ..color = AppColors.neonCyan.withValues(alpha: 0.33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final Paint red = Paint()
      ..color = AppColors.recallRed.withValues(alpha: 0.33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final Path p1 = Path();
    final Path p2 = Path();

    for (int x = 0; x <= size.width.toInt(); x += 2) {
      final double dx = x.toDouble();
      final double y1 =
          size.height * 0.45 + math.sin((dx / 24) + (phase * math.pi * 2)) * 8;
      final double y2 =
          size.height * 0.60 +
          math.cos((dx / 20) + (phase * math.pi * 2.5)) * 6;
      if (x == 0) {
        p1.moveTo(dx, y1);
        p2.moveTo(dx, y2);
      } else {
        p1.lineTo(dx, y1);
        p2.lineTo(dx, y2);
      }
    }
    canvas.drawPath(p1, cyan);
    canvas.drawPath(p2, red);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
