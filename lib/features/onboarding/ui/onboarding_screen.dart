import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  int _current = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.event_note_rounded,
      iconColor: Color(0xFF00E5FF),
      tag: 'PLAN',
      title: 'BUILD YOUR FIRST PLAN',
      subtitle: 'Create, schedule, and review',
      body:
          'Create tasks, routines, goals, and notes. Choose when they happen, then view everything on your Timeline. ChronoSpark helps turn plans into progress.',
      statusLine: 'START HERE',
    ),
    _Slide(
      icon: Icons.auto_awesome_rounded,
      iconColor: Color(0xFF9B8AFB),
      tag: 'SMART GUIDANCE',
      title: 'SMARTER PLANNING',
      subtitle: 'Guidance when you need it',
      body:
          'Smart Planner helps you decide what to focus on next. SI Console helps you understand your goals, progress, and planning signals. Use them when you want extra guidance.',
      statusLine: 'USE WHEN NEEDED',
    ),
  ];

  static const int _totalPages = 2;

  static const String _eventOnboardingStartedLegacy = 'onboarding_started';
  static const String _eventOnboardingStartedCanonical = 'first_setup_started';
  static const String _eventOnboardingSkippedLegacy = 'onboarding_skipped';
  static const String _eventOnboardingSkippedCanonical = 'first_setup_skipped';
  static const String _eventOnboardingStepAdvancedLegacy =
      'onboarding_step_advanced';
  static const String _eventOnboardingStepAdvancedCanonical =
      'first_setup_step_advanced';
  static const String _eventMissionActivationStartedLegacy =
      'mission_zero_activation_started';
  static const String _eventMissionActivationStartedCanonical =
      'first_setup_activation_started';
  static const String _eventMissionActivationStartFailedLegacy =
      'mission_zero_activation_start_failed';
  static const String _eventMissionActivationStartFailedCanonical =
      'first_setup_activation_start_failed';

  @override
  void initState() {
    super.initState();
    _restoreOnboardingProgress();
    _trackCompat(
      legacyEvent: _eventOnboardingStartedLegacy,
      canonicalEvent: _eventOnboardingStartedCanonical,
    );
  }

  Future<void> _restoreOnboardingProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stepKey = _resolveStepKey();
    final int restoredStep =
        (prefs.getInt(stepKey) ?? prefs.getInt(onboardingStepStorageKey) ?? 0)
            .clamp(0, _totalPages - 1);
    if (!mounted) {
      return;
    }
    setState(() => _current = restoredStep);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _page.jumpToPage(restoredStep);
    });
  }

  Future<void> _persistOnboardingProgress(int step) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stepKey = _resolveStepKey();
    await prefs.setInt(stepKey, step);
    await prefs.setInt(onboardingStepStorageKey, step);
  }

  String _resolveStepKey() {
    final String? userId = _currentSupabaseUserId();
    if (userId == null) {
      return onboardingStepStorageKey;
    }
    return onboardingStepStorageKeyForUser(userId);
  }

  String? _currentSupabaseUserId() {
    try {
      if (!Env.isSupabaseConfigured) {
        return null;
      }
      final String? userId = sb.Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.trim().isEmpty) {
        return null;
      }
      return userId.trim();
    } on Object {
      return null;
    }
  }

  Future<bool> _onWillPop() async {
    if (_current > 0) {
      _page.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return false;
    }

    final bool shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Exit setup?'),
              content: const Text(
                'You can continue later. Your progress is saved.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Keep setting up'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        ) ??
        false;

    return shouldExit;
  }

  Future<void> _handleBackNavigation() async {
    final bool allowExit = await _onWillPop();
    if (!allowExit || !mounted) {
      return;
    }

    final bool popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      // Do not close the desktop app from onboarding.
      // Stay on the current screen and let router/profile guards resolve flow.
      return;
    }
  }

  Future<void> _beginMissionZero() async {
    try {
      debugPrint('CHRONOSPARK_ONBOARDING_START_SETUP_TAPPED');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String resolvedName = _fallbackProfileName();

      ref
          .read(profileProvider.notifier)
          .ensureProfile(preferredName: resolvedName);

      await SharedPrefsService.saveBoolWithPrefs(
        prefs,
        onboardingCompleteStorageKey,
        true,
      );
      await SharedPrefsService.saveBoolWithPrefs(
        prefs,
        creatorFirstItemCreatedStorageKey,
        false,
      );
      await SharedPrefsService.saveBoolWithPrefs(
        prefs,
        timelineFirstActionCompletedStorageKey,
        false,
      );
      await _writeCanonicalOnboardingState(
        prefs: prefs,
        complete: true,
        userId: null,
      );
      final String? userId = _currentSupabaseUserId();
      if (userId != null) {
        await SharedPrefsService.saveBoolWithPrefs(
          prefs,
          onboardingCompleteStorageKeyForUser(userId),
          true,
        );
        await SharedPrefsService.saveBoolWithPrefs(
          prefs,
          creatorFirstItemCreatedStorageKeyForUser(userId),
          false,
        );
        await SharedPrefsService.saveBoolWithPrefs(
          prefs,
          timelineFirstActionCompletedStorageKeyForUser(userId),
          false,
        );
        await _writeCanonicalOnboardingState(
          prefs: prefs,
          complete: true,
          userId: userId,
        );
        await SharedPrefsService.saveIntWithPrefs(
          prefs,
          onboardingStepStorageKeyForUser(userId),
          0,
        );
      }
      await SharedPrefsService.saveIntWithPrefs(
        prefs,
        onboardingStepStorageKey,
        0,
      );
      _trackCompat(
        legacyEvent: _eventMissionActivationStartedLegacy,
        canonicalEvent: _eventMissionActivationStartedCanonical,
        params: <String, Object?>{'entry_surface': 'setup_start'},
      );
      if (!mounted) return;

      ref.read(onboardingCompleteProvider.notifier).set(true);
      ref.read(creatorFirstItemCreatedProvider.notifier).set(false);
      ref.read(timelineFirstActionCompletedProvider.notifier).set(false);
      ref
          .read(onboardingStatusProvider.notifier)
          .set(OnboardingStatus.complete);
      debugPrint('CHRONOSPARK_ONBOARDING_MARKED_COMPLETE_FOR_MISSION_ZERO');
      final bool isAuthenticated = ref
          .read(intelligenceStateProvider)
          .auth
          .isAuthenticated;
      debugPrint(
        'CHRONOSPARK_ONBOARDING_NAVIGATING: authenticated=$isAuthenticated',
      );
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(isAuthenticated ? RoutePaths.creator : RoutePaths.login);
      }
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'onboarding',
        'Onboarding completion failed.',
        error,
        stackTrace,
      );
      _trackCompat(
        legacyEvent: _eventMissionActivationStartFailedLegacy,
        canonicalEvent: _eventMissionActivationStartFailedCanonical,
        params: <String, Object?>{'error': error.toString()},
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start setup. Please try again.'),
        ),
      );
    }
  }

  String _fallbackProfileName() {
    try {
      if (!Env.isSupabaseConfigured) {
        return 'Creator';
      }
      final String? email = sb.Supabase.instance.client.auth.currentUser?.email;
      if (email == null || email.trim().isEmpty) {
        return 'Creator';
      }
      final String localPart = email.split('@').first.trim();
      if (localPart.isEmpty) {
        return 'Creator';
      }
      return localPart;
    } on Object {
      return 'Creator';
    }
  }

  Future<void> _writeCanonicalOnboardingState({
    required SharedPreferences prefs,
    required bool complete,
    required String? userId,
  }) async {
    final String completeKey = userId == null
        ? onboardingCompleteStorageKey
        : onboardingCompleteStorageKeyForUser(userId);
    final String versionKey = userId == null
        ? onboardingContentVersionStorageKey
        : onboardingContentVersionStorageKeyForUser(userId);
    final String canonicalKey = onboardingCanonicalStateStorageKeyForUser(
      userId,
    );

    await SharedPrefsService.saveBoolWithPrefs(prefs, completeKey, complete);
    await SharedPrefsService.saveIntWithPrefs(
      prefs,
      versionKey,
      onboardingContentVersion,
    );
    await SharedPrefsService.saveStringWithPrefs(
      prefs,
      canonicalKey,
      jsonEncode(
        buildOnboardingCanonicalStatePayload(
          complete: complete,
          version: onboardingContentVersion,
        ),
      ),
    );
  }

  void _next() {
    if (_current < _totalPages - 1) {
      _trackCompat(
        legacyEvent: _eventOnboardingStepAdvancedLegacy,
        canonicalEvent: _eventOnboardingStepAdvancedCanonical,
        params: <String, Object?>{'step_index': _current},
      );
      _page.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _beginMissionZero();
    }
  }

  void _trackCompat({
    required String legacyEvent,
    required String canonicalEvent,
    Map<String, Object?>? params,
  }) {
    if (params == null) {
      AppAnalytics.track(legacyEvent);
      AppAnalytics.track(canonicalEvent);
      return;
    }

    AppAnalytics.track(legacyEvent, params: params);
    AppAnalytics.track(canonicalEvent, params: params);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final bool landscape = media.width > media.height;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }
        unawaited(_handleBackNavigation());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Starfield background
            const Positioned.fill(child: _StarfieldBackground()),
            const Positioned.fill(child: _HudPulseOverlay()),

            // Page content
            PageView.builder(
              controller: _page,
              onPageChanged: (i) {
                setState(() => _current = i);
                unawaited(_persistOnboardingProgress(i));
              },
              itemCount: _totalPages,
              itemBuilder: (context, i) {
                if (i < _slides.length) {
                  return _SlideView(slide: _slides[i]);
                }
                return _SlideView(slide: _slides.last);
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
                              child: _PhaseIndicator(
                                current: _current,
                                total: _totalPages,
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 220,
                              child: _GradientButton(
                                label: _current < _totalPages - 1
                                    ? 'NEXT'
                                    : 'START SETUP',
                                onTap: _next,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (_current < _totalPages - 1)
                              GestureDetector(
                                onTap: () {
                                  _trackCompat(
                                    legacyEvent: _eventOnboardingSkippedLegacy,
                                    canonicalEvent:
                                        _eventOnboardingSkippedCanonical,
                                    params: <String, Object?>{
                                      'step_index': _current,
                                    },
                                  );
                                  _beginMissionZero();
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
                              const SizedBox(width: 40),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PhaseIndicator(
                              current: _current,
                              total: _totalPages,
                            ),
                            const SizedBox(height: 20),

                            // Primary action button
                            _GradientButton(
                              label: _current < _totalPages - 1
                                  ? 'NEXT'
                                  : 'START SETUP',
                              onTap: _next,
                            ),
                            const SizedBox(height: 14),

                            // Skip link
                            if (_current < _totalPages - 1)
                              GestureDetector(
                                onTap: () {
                                  _trackCompat(
                                    legacyEvent: _eventOnboardingSkippedLegacy,
                                    canonicalEvent:
                                        _eventOnboardingSkippedCanonical,
                                    params: <String, Object?>{
                                      'step_index': _current,
                                    },
                                  );
                                  _beginMissionZero();
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
    required this.statusLine,
  });

  final IconData icon;
  final Color iconColor;
  final String tag;
  final String title;
  final String subtitle;
  final String body;
  final String statusLine;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  Widget _buildPulseAura(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    MotionProfile motionProfile = MotionProfile.standard;
    try {
      motionProfile = ProviderScope.containerOf(
        context,
        listen: true,
      ).read(motionProfileProvider);
    } on Object {
      motionProfile = MotionProfile.standard;
    }
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool shouldRepeat = switch (motionProfile) {
      MotionProfile.calm => false,
      MotionProfile.standard => true,
      MotionProfile.expressive => true,
    };
    final double sizeScale = switch (motionProfile) {
      MotionProfile.calm => 0.88,
      MotionProfile.standard => 1.0,
      MotionProfile.expressive => 1.08,
    };
    return Lottie.asset(
      AppAssets.animFocusPulse,
      width: width * sizeScale,
      height: height * sizeScale,
      repeat: !reduceMotion && shouldRepeat,
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
                        _SignalReveal(
                          delay: const Duration(milliseconds: 20),
                          child: Container(
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
                                _buildPulseAura(context, width: 86, height: 86),
                                Icon(
                                  slide.icon,
                                  color: slide.iconColor,
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SignalReveal(
                          delay: const Duration(milliseconds: 120),
                          child: Container(
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
                        ),
                        const SizedBox(height: 14),
                        _SignalReveal(
                          delay: const Duration(milliseconds: 240),
                          child: _StatusLine(text: slide.statusLine),
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
                        _SignalReveal(
                          delay: const Duration(milliseconds: 140),
                          child: ShaderMask(
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
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.9,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SignalReveal(
                          delay: const Duration(milliseconds: 240),
                          child: Text(
                            slide.subtitle,
                            style: TextStyle(
                              color: slide.iconColor.withValues(alpha: 0.75),
                              fontSize: 16,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SignalReveal(
                          delay: const Duration(milliseconds: 360),
                          child: Container(
                            width: 48,
                            height: 2,
                            decoration: BoxDecoration(
                              color: slide.iconColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SignalReveal(
                          delay: const Duration(milliseconds: 460),
                          child: Text(
                            slide.body,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                            ),
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
              _SignalReveal(
                delay: const Duration(milliseconds: 20),
                child: Container(
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
                      _buildPulseAura(context, width: 66, height: 66),
                      Icon(slide.icon, color: slide.iconColor, size: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SignalReveal(
                delay: const Duration(milliseconds: 120),
                child: Container(
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
              ),
              const SizedBox(height: 12),
              _SignalReveal(
                delay: const Duration(milliseconds: 240),
                child: _StatusLine(text: slide.statusLine),
              ),
              const SizedBox(height: 12),
              _SignalReveal(
                delay: const Duration(milliseconds: 180),
                child: ShaderMask(
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
                      letterSpacing: 1.8,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _SignalReveal(
                delay: const Duration(milliseconds: 280),
                child: Text(
                  slide.subtitle,
                  style: TextStyle(
                    color: slide.iconColor.withValues(alpha: 0.75),
                    fontSize: 14,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SignalReveal(
                delay: const Duration(milliseconds: 360),
                child: Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: slide.iconColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SignalReveal(
                delay: const Duration(milliseconds: 460),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    slide.body,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.75,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
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
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      'PLAN',
      'GUIDE',
    ].take(total).toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(labels.length, (int i) {
              final bool active = i == current;
              return Padding(
                padding: EdgeInsets.only(
                  right: i == labels.length - 1 ? 0 : 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: active
                            ? AppColors.neonCyan
                            : Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.neonCyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.neonCyan,
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SignalReveal extends StatefulWidget {
  const _SignalReveal({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_SignalReveal> createState() => _SignalRevealState();
}

class _SignalRevealState extends State<_SignalReveal> {
  bool _visible = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _revealTimer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MotionProfile motionProfile = MotionProfile.standard;
    try {
      motionProfile = ProviderScope.containerOf(
        context,
        listen: true,
      ).read(motionProfileProvider);
    } on Object {
      motionProfile = MotionProfile.standard;
    }
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return widget.child;
    }
    final Duration duration = switch (motionProfile) {
      MotionProfile.calm => const Duration(milliseconds: 380),
      MotionProfile.standard => const Duration(milliseconds: 520),
      MotionProfile.expressive => const Duration(milliseconds: 620),
    };
    return AnimatedSlide(
      duration: duration,
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

class _HudPulseOverlay extends StatefulWidget {
  const _HudPulseOverlay();

  @override
  State<_HudPulseOverlay> createState() => _HudPulseOverlayState();
}

class _HudPulseOverlayState extends State<_HudPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MotionProfile motionProfile = MotionProfile.standard;
    try {
      motionProfile = ProviderScope.containerOf(
        context,
        listen: true,
      ).read(motionProfileProvider);
    } on Object {
      motionProfile = MotionProfile.standard;
    }
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return const SizedBox.shrink();
    }
    final Duration cycle = switch (motionProfile) {
      MotionProfile.calm => const Duration(seconds: 6),
      MotionProfile.standard => const Duration(seconds: 4),
      MotionProfile.expressive => const Duration(seconds: 3),
    };
    if (_controller.duration != cycle) {
      _controller.duration = cycle;
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double scanY = constraints.maxHeight * (0.2 + (0.65 * t));
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.35),
                          radius: 1.0,
                          colors: <Color>[
                            AppColors.neonCyan.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: scanY,
                    child: Opacity(
                      opacity: 0.12,
                      child: Container(
                        height: 1.5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              AppColors.neonCyan,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
    MotionProfile motionProfile = MotionProfile.standard;
    try {
      motionProfile = ProviderScope.containerOf(
        context,
        listen: true,
      ).read(motionProfileProvider);
    } on Object {
      motionProfile = MotionProfile.standard;
    }
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return CustomPaint(
        painter: _StarPainter(_stars, 0),
        child: const SizedBox.expand(),
      );
    }
    final Duration cycle = switch (motionProfile) {
      MotionProfile.calm => const Duration(seconds: 6),
      MotionProfile.standard => const Duration(seconds: 4),
      MotionProfile.expressive => const Duration(seconds: 3),
    };
    if (_ctrl.duration != cycle) {
      _ctrl.duration = cycle;
      if (!_ctrl.isAnimating) {
        _ctrl.repeat();
      }
    }
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
