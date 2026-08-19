import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
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
  late final PageController _page;
  late int _current;
  final _nameCtrl = TextEditingController();
  final GlobalKey _welcomeActionKey = GlobalKey(debugLabel: 'welcome-continue');
  final GlobalKey _nameFieldKey = GlobalKey(debugLabel: 'name-field');
  bool _submitting = false;

  static const _totalPages = OnboardingContentContract.pageCount;

  @override
  void initState() {
    super.initState();
    _current = ref.read(onboardingWelcomeCompleteProvider) ? 1 : 0;
    _page = PageController(initialPage: _current);
    _nameCtrl.addListener(_handleNameChanged);
    AppAnalytics.track('onboarding_started');
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _completeWelcome() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingWelcomeCompleteStorageKey, true);
      if (!mounted) return;
      ref.read(onboardingWelcomeCompleteProvider.notifier).set(true);
      AppAnalytics.track('onboarding_welcome_completed');

      final bool isAuthenticated = ref
          .read(intelligenceStateProvider)
          .auth
          .isAuthenticated;
      if (isAuthenticated) {
        setState(() {
          _current = 1;
          _submitting = false;
        });
        _page.jumpToPage(1);
      } else {
        final GoRouter? router = GoRouter.maybeOf(context);
        if (router != null) {
          context.go(ref.read(routeSurfaceProvider).login);
        }
      }
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'onboarding',
        'Welcome completion failed.',
        error,
        stackTrace,
      );
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to continue. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _complete() async {
    if (_submitting) return;
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter what you want to be called.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ref.read(profileProvider.notifier).updateName(name);

      await prefs.setBool(onboardingCompleteStorageKey, true);
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        OnboardingContentContract.currentVersion,
      );
      await ref.read(accountOnboardingCompleteProvider.notifier).complete();
      AppAnalytics.track(
        'onboarding_completed',
        params: <String, Object?>{'has_display_name': true},
      );
      if (!mounted) return;

      ref.read(onboardingCompleteProvider.notifier).set(true);
      final routes = ref.read(routeSurfaceProvider);
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(routes.creator);
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
      setState(() => _submitting = false);
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
    if (_current == 0) {
      unawaited(_completeWelcome());
    } else {
      unawaited(_complete());
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.removeListener(_handleNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool hasName = _nameCtrl.text.trim().isNotEmpty;
    final String continueToLogin = l10n.isSpanish
        ? 'CONTINUAR AL ACCESO'
        : 'CONTINUE TO LOGIN';
    final String continueToCreator = l10n.isSpanish
        ? 'CONTINUAR A CREADOR'
        : 'CONTINUE TO CREATOR';
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
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _totalPages,
            itemBuilder: (context, i) {
              if (i < slides.length) return _SlideView(slide: slides[i]);
              return _PersonalizationSlide(
                nameCtrl: _nameCtrl,
                nameFieldKey: _nameFieldKey,
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
                            child: KeyedSubtree(
                              key: _welcomeActionKey,
                              child: _GradientButton(
                                label: _current == 0
                                    ? continueToLogin
                                    : continueToCreator,
                                onTap: _next,
                              ),
                            ),
                          ),
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
                          KeyedSubtree(
                            key: _welcomeActionKey,
                            child: _GradientButton(
                              label: _current == 0
                                  ? continueToLogin
                                  : continueToCreator,
                              onTap: _next,
                            ),
                          ),
                          const SizedBox(height: 17),
                        ],
                      ),
              ),
            ),
          ),
          InteractiveTutorialOverlay(
            targetKey: _current == 0 ? _welcomeActionKey : _nameFieldKey,
            stepLabel: _current == 0
                ? (l10n.isSpanish
                      ? 'Configuración 1 de 4'
                      : 'First setup 1 of 4')
                : (l10n.isSpanish
                      ? 'Configuración 3 de 4'
                      : 'First setup 3 of 4'),
            title: _current == 0
                ? (l10n.isSpanish
                      ? 'Bienvenido a ChronoSpark'
                      : 'Welcome to ChronoSpark')
                : l10n.text(ChronoSparkString.nameQuestion),
            body: _current == 0
                ? (l10n.isSpanish
                      ? 'Comienza aquí e inicia sesión para que tu primera tarea pertenezca a tu cuenta.'
                      : 'Start here, then sign in so your first task belongs to your account.')
                : (l10n.isSpanish
                      ? 'Escribe el nombre que debe usar ChronoSpark. Se guarda antes de comenzar la lección interactiva de Creador.'
                      : 'Enter the name ChronoSpark should use. This is saved before your interactive Creator lesson begins.'),
            primaryLabel: _submitting
                ? (l10n.isSpanish ? 'Espera' : 'Please wait')
                : _current == 0
                ? (l10n.isSpanish ? 'Continuar al acceso' : 'Continue to login')
                : (l10n.isSpanish
                      ? 'Continuar a Creador'
                      : 'Continue to Creator'),
            primaryEnabled: !_submitting && (_current == 0 || hasName),
            onPrimary: _next,
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
    required this.nameFieldKey,
  });

  final TextEditingController nameCtrl;
  final GlobalKey nameFieldKey;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
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
                  key: nameFieldKey,
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textInputAction: TextInputAction.done,
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
                                      .text(ChronoSparkString.nameQuestion)
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
                      l10n.text(ChronoSparkString.nameQuestion).toUpperCase(),
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
