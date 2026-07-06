import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  int _current = 0;
  final _nameCtrl = TextEditingController();
  String? _selectedGoalType;

  static const _totalPages = 6; // 5 info slides + 1 personalization

  static const _slides = [
    _Slide(
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFF00E5FF),
      tag: 'WELCOME',
      title: 'CHRONOSPARK',
      subtitle: 'Temporal Intelligence System',
      body:
          'Your AI life intelligence core. ChronoSpark reads your energy, tracks your evolution, and helps you execute at your highest level every day.',
    ),
    _Slide(
      icon: Icons.psychology_rounded,
      iconColor: Color(0xFF9B8AFB),
      tag: 'SMART COACH',
      title: 'LIFE GUIDANCE',
      subtitle: 'AI-powered personal coaching',
      body:
          'Smart Coach reads your emotional state, energy signature, and behavior patterns to generate precise guidance. This is not a checklist bot. It is your strategy layer.',
    ),
    _Slide(
      icon: Icons.timer_rounded,
      iconColor: Color(0xFF00E5FF),
      tag: 'TRAJECTORY ENGINE',
      title: 'PREDICTIONS & ACTIONS',
      subtitle: 'Own your next move',
      body:
          'Trajectory Engine converts behavior signals into forward predictions and tactical actions so you can move with clarity and force.',
    ),
    _Slide(
      icon: Icons.trending_up_rounded,
      iconColor: Color(0xFF00E5FF),
      tag: 'ACTIVITY LEDGER',
      title: 'VERIFIED HISTORY',
      subtitle: 'Review what actually happened',
      body:
          'Activity Ledger records completed actions and milestones in one trusted timeline so you can audit execution and upgrade your system.',
    ),
    _Slide(
      icon: Icons.touch_app_rounded,
      iconColor: Color(0xFF00E5FF),
      tag: 'PAGE GUIDE',
      title: 'WHAT TO CLICK',
      subtitle: 'Quick control map',
      body:
          'Nexus: scan signals, choose one next move.\nTrajectory: read prediction, then open Flowmap for branches.\nCreator: forge manual tasks only when needed.\nActivity Ledger: audit completed actions and patterns.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    AppAnalytics.track('onboarding_started');
  }

  Future<void> _complete() async {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      ref.read(profileProvider.notifier).updateName(name);
    }
    if (_selectedGoalType != null) {
      await SharedPrefsService.save('primary_goal_type', _selectedGoalType!);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompleteStorageKey, true);
    await prefs.setInt(
      onboardingContentVersionStorageKey,
      TutorialContent.contentVersion,
    );
    AppAnalytics.track(
      'onboarding_completed',
      params: <String, Object?>{'selected_goal_type': _selectedGoalType ?? ''},
    );
    if (!mounted) return;
    ref.read(onboardingCompleteProvider.notifier).set(true);
  }

  void _next() {
    if (_current < _totalPages - 1) {
      AppAnalytics.track(
        'onboarding_step_advanced',
        params: <String, Object?>{'step_index': _current},
      );
      _page.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Starfield background
          const Positioned.fill(child: _StarfieldBackground()),

          // Page content
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _totalPages,
            itemBuilder: (context, i) {
              if (i < _slides.length) return _SlideView(slide: _slides[i]);
              return _PersonalizationSlide(
                nameCtrl: _nameCtrl,
                selectedGoalType: _selectedGoalType,
                onGoalTypeSelected: (v) =>
                    setState(() => _selectedGoalType = v),
              );
            },
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (i) {
                        final bool active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.neonCyan
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonCyan.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Primary action button
                    _GradientButton(
                      label: _current == _totalPages - 1
                          ? 'INITIALIZE SYSTEM'
                          : 'NEXT',
                      onTap: _next,
                    ),
                    const SizedBox(height: 14),

                    // Skip link
                    if (_current < _totalPages - 1)
                      GestureDetector(
                        onTap: () {
                          AppAnalytics.track(
                            'onboarding_skipped',
                            params: <String, Object?>{'step_index': _current},
                          );
                          _complete();
                        },
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 17),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String tag;
  final String title;
  final String subtitle;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon orb
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.iconColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: slide.iconColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: slide.iconColor.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(slide.icon, color: slide.iconColor, size: 32),
            ),
            const SizedBox(height: 28),

            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: slide.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: slide.iconColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                slide.tag,
                style: TextStyle(
                  color: slide.iconColor,
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, slide.iconColor.withValues(alpha: 0.8)],
              ).createShader(bounds),
              child: Text(
                slide.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              slide.subtitle,
              style: TextStyle(
                color: slide.iconColor.withValues(alpha: 0.75),
                fontSize: 13,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Divider
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: slide.iconColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 22),

            // Body
            Text(
              slide.body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalizationSlide extends StatelessWidget {
  const _PersonalizationSlide({
    required this.nameCtrl,
    required this.selectedGoalType,
    required this.onGoalTypeSelected,
  });

  final TextEditingController nameCtrl;
  final String? selectedGoalType;
  final ValueChanged<String> onGoalTypeSelected;

  static const _goalTypes = [
    ('Focus & Productivity', Icons.bolt_rounded, Color(0xFF00E5FF)),
    ('Personal Growth', Icons.trending_up_rounded, Color(0xFF9B8AFB)),
    ('Mental Wellness', Icons.self_improvement_rounded, Color(0xFF00E5FF)),
    ('Just exploring', Icons.explore_rounded, Color(0xFFFFC857)),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'PERSONALIZE',
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, AppColors.neonCyan],
              ).createShader(bounds),
              child: const Text(
                'YOUR MISSION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help us calibrate your experience',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 13,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'WHAT SHOULD I CALL YOU?',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.25),
                ),
              ),
              child: TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Enter your name...',
                  hintStyle: TextStyle(color: Colors.white24),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PRIMARY GOAL',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _goalTypes.map((entry) {
                final (label, icon, color) = entry;
                final selected = selectedGoalType == label;
                return GestureDetector(
                  onTap: () => onGoalTypeSelected(label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.1),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: selected ? color : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? color : Colors.white54,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF6C8CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}

class _StarfieldBackground extends StatefulWidget {
  const _StarfieldBackground();

  @override
  State<_StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<_StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<_Star> _stars = List.generate(
    80,
    (i) => _Star(
      x: math.Random().nextDouble(),
      y: math.Random().nextDouble(),
      size: math.Random().nextDouble() * 1.8 + 0.4,
      speed: math.Random().nextDouble() * 0.6 + 0.2,
      phase: math.Random().nextDouble() * math.pi * 2,
    ),
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: _StarPainter(_stars, _ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.stars, this.t);

  final List<_Star> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in stars) {
      final alpha =
          (0.35 + 0.45 * math.sin(t * math.pi * 2 * star.speed + star.phase))
              .clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}
