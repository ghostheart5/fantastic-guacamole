import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
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

  static const _totalPages = OnboardingContentContract.pageCount;

  @override
  void initState() {
    super.initState();
    AppAnalytics.track('onboarding_started');
  }

  Future<void> _complete() async {
    try {
      final PreferenceService preferenceService = PreferenceService();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String name = _nameCtrl.text.trim();
      final String? selectedGoalType = _selectedGoalType;

      if (name.isNotEmpty) {
        await ref.read(profileProvider.notifier).updateName(name);
      }
      if (selectedGoalType != null && selectedGoalType.trim().isNotEmpty) {
        await prefs.setString('primary_goal_type', selectedGoalType);
        await preferenceService.setUserPreference(
          'primary_goal_type',
          selectedGoalType,
        );
        await ref
            .read(personalizationProfileProvider.notifier)
            .updateGoalCategory(selectedGoalType);
      }

      await prefs.setBool(onboardingCompleteStorageKey, true);
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        OnboardingContentContract.currentVersion,
      );
      AppAnalytics.track(
        'onboarding_completed',
        params: <String, Object?>{'selected_goal_type': selectedGoalType ?? ''},
      );
      if (!mounted) return;

      ref.read(onboardingCompleteProvider.notifier).set(true);
      final bool isAuthenticated = ref
          .read(intelligenceStateProvider)
          .auth
          .isAuthenticated;
      final routes = ref.read(routeSurfaceProvider);
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(isAuthenticated ? '/' : routes.login);
      }
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'onboarding',
        'Onboarding completion failed.',
        error,
        stackTrace,
      );
      AppAnalytics.track(
        'onboarding_complete_failed',
        params: <String, Object?>{'error': error.toString()},
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ChronoSparkLocalizations.of(
              context,
            ).text(ChronoSparkString.onboardingFinishError),
          ),
        ),
      );
    }
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

  void _skip() {
    AppAnalytics.track(
      'onboarding_skipped',
      params: <String, Object?>{'step_index': _current},
    );
    _complete();
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final List<_Slide> slides = <_Slide>[
      _Slide(
        icon: Icons.bolt_rounded,
        iconColor: const Color(0xFF00E5FF),
        tag: l10n.text(ChronoSparkString.welcome),
        title: 'CHRONOSPARK',
        subtitle: l10n.text(ChronoSparkString.livingDecisionSystem),
        body: l10n.text(ChronoSparkString.onboardingWelcomeBody),
      ),
    ];
    final media = MediaQuery.sizeOf(context);
    final bool landscape = media.width > media.height;
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
              if (i < slides.length) return _SlideView(slide: slides[i]);
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
                padding: EdgeInsets.fromLTRB(24, 0, 24, landscape ? 14 : 24),
                child: landscape
                    ? Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_totalPages, (i) {
                                final bool active = i == _current;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: active ? 20 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.neonCyan
                                        : Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: AppColors.neonCyan
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 180,
                            child: _GradientButton(
                              label: _current == _totalPages - 1
                                  ? l10n
                                        .text(ChronoSparkString.initialize)
                                        .toUpperCase()
                                  : l10n
                                        .text(ChronoSparkString.next)
                                        .toUpperCase(),
                              onTap: _next,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_current < _totalPages - 1)
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: _skip,
                                child: Text(
                                  l10n
                                      .text(ChronoSparkString.skip)
                                      .toUpperCase(),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 40),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dot indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_totalPages, (i) {
                              final bool active = i == _current;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
                                            color: AppColors.neonCyan
                                                .withValues(alpha: 0.6),
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
                                ? l10n
                                      .text(ChronoSparkString.initializeSystem)
                                      .toUpperCase()
                                : l10n
                                      .text(ChronoSparkString.next)
                                      .toUpperCase(),
                            onTap: _next,
                          ),
                          const SizedBox(height: 14),

                          // Skip link
                          if (_current < _totalPages - 1)
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: _skip,
                                child: Text(
                                  l10n
                                      .text(ChronoSparkString.skip)
                                      .toUpperCase(),
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

  Widget _buildPulseAura({required double width, required double height}) {
    return Lottie.asset(
      AppAssets.animSignalPulse,
      width: width,
      height: height,
      repeat: true,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: width, height: height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wideLayout = constraints.maxWidth >= 760;
        final bool landscapeCompact =
            constraints.maxWidth > constraints.maxHeight * 1.15;
        final EdgeInsets padding = EdgeInsets.fromLTRB(
          wideLayout ? (landscapeCompact ? 40 : 56) : 28,
          wideLayout ? (landscapeCompact ? 32 : 64) : 40,
          wideLayout ? (landscapeCompact ? 40 : 56) : 28,
          wideLayout ? (landscapeCompact ? 152 : 188) : 160,
        );

        Widget content;
        if (wideLayout) {
          content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: landscapeCompact ? 980 : 1040,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: landscapeCompact ? 310 : 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
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
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildPulseAura(width: 86, height: 86),
                              Icon(
                                slide.icon,
                                color: slide.iconColor,
                                size: 36,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              slide.iconColor.withValues(alpha: 0.8),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            slide.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide.subtitle,
                          style: TextStyle(
                            color: slide.iconColor.withValues(alpha: 0.75),
                            fontSize: 15,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: 48,
                          height: 2,
                          decoration: BoxDecoration(
                            color: slide.iconColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          slide.body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 17,
                            height: 1.75,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildPulseAura(width: 66, height: 66),
                    Icon(slide.icon, color: slide.iconColor, size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Colors.white,
                    slide.iconColor.withValues(alpha: 0.8),
                  ],
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
              Text(
                slide.subtitle,
                style: TextStyle(
                  color: slide.iconColor.withValues(alpha: 0.75),
                  fontSize: 13,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  color: slide.iconColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 18),
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
          );
        }

        return SafeArea(
          child: SingleChildScrollView(padding: padding, child: content),
        );
      },
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
    ('execution', Icons.bolt_rounded, Color(0xFF00E5FF)),
    ('growth', Icons.trending_up_rounded, Color(0xFF9B8AFB)),
    ('wellness', Icons.self_improvement_rounded, Color(0xFF00E5FF)),
    ('exploring', Icons.explore_rounded, Color(0xFFFFC857)),
  ];

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    String goalLabel(String id) => switch (id) {
      'execution' => l10n.text(ChronoSparkString.goalExecution),
      'growth' => l10n.text(ChronoSparkString.goalGrowth),
      'wellness' => l10n.text(ChronoSparkString.goalWellness),
      _ => l10n.text(ChronoSparkString.goalExplore),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wideLayout = constraints.maxWidth >= 820;
        final bool landscapeCompact =
            constraints.maxWidth > constraints.maxHeight * 1.15;
        final EdgeInsets padding = EdgeInsets.fromLTRB(
          wideLayout ? (landscapeCompact ? 40 : 56) : 28,
          wideLayout ? (landscapeCompact ? 32 : 64) : 40,
          wideLayout ? (landscapeCompact ? 40 : 56) : 28,
          wideLayout ? (landscapeCompact ? 150 : 188) : 160,
        );
        final int goalColumns = constraints.maxWidth >= 980
            ? 4
            : (landscapeCompact ? 3 : 2);

        final Widget formCard = Container(
          width: wideLayout ? (landscapeCompact ? 440 : 460) : double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.18),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.text(ChronoSparkString.nameQuestion).toUpperCase(),
                style: const TextStyle(
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
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.text(ChronoSparkString.name),
                    hintText: l10n.text(ChronoSparkString.nameHint),
                    hintStyle: const TextStyle(color: Colors.white24),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.text(ChronoSparkString.primaryGoal).toUpperCase(),
                style: const TextStyle(
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
                crossAxisCount: goalColumns,
                childAspectRatio: goalColumns >= 4
                    ? 2.1
                    : (landscapeCompact ? 3.0 : 2.6),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: _goalTypes.map((entry) {
                  final (id, icon, color) = entry;
                  final String label = goalLabel(id);
                  final selected = selectedGoalType == id;
                  return Semantics(
                    selected: selected,
                    label: label,
                    child: ChoiceChip(
                      selected: selected,
                      onSelected: (_) => onGoalTypeSelected(id),
                      avatar: Icon(icon, color: color, size: 18),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      ),
                      showCheckmark: true,
                      selectedColor: color.withValues(alpha: 0.2),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      side: BorderSide(
                        color: selected
                            ? color.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.text(ChronoSparkString.onboardingPrivacy),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );

        final Widget content = wideLayout
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: landscapeCompact ? 1020 : 1080,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40, top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n
                                    .text(ChronoSparkString.personalize)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.neonCyan,
                                  fontSize: 10,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        AppColors.neonCyan,
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  l10n
                                      .text(ChronoSparkString.lifeDirection)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l10n.text(
                                  ChronoSparkString.calibrateExperience,
                                ),
                                style: const TextStyle(
                                  color: AppColors.neonCyan,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const SizedBox(
                                width: 48,
                                child: Divider(
                                  color: AppColors.neonCyan,
                                  thickness: 2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.text(ChronoSparkString.onboardingWideBody),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.7,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      formCard,
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      l10n.text(ChronoSparkString.personalize).toUpperCase(),
                      style: const TextStyle(
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
                    child: Text(
                      l10n.text(ChronoSparkString.lifeDirection).toUpperCase(),
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
                  Text(
                    l10n.text(ChronoSparkString.calibrateExperience),
                    style: const TextStyle(
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
                  const SizedBox(height: 20),
                  Text(
                    l10n.text(ChronoSparkString.onboardingCompactBody),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.65,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 18),
                  formCard,
                ],
              );

        return SafeArea(
          child: SingleChildScrollView(
            padding: padding,
            // This slide owns the only text field in onboarding, so dragging
            // the sheet should dismiss the keyboard the same way login does.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: content,
          ),
        );
      },
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        child: Text(label),
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
