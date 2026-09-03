import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    this.loginLocation,
    this.completedLocation,
    super.key,
  });

  final String? loginLocation;
  final String? completedLocation;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _page;
  late int _current;
  final _helpCtrl = TextEditingController();
  double? _capacity;
  bool _submitting = false;

  static const _totalPages = OnboardingContentContract.pageCount;

  @override
  void initState() {
    super.initState();
    _current = ref.read(onboardingWelcomeCompleteProvider) ? 1 : 0;
    _page = PageController(initialPage: _current);
    AppAnalytics.track('onboarding_started');
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
          context.go(
            widget.loginLocation ?? ref.read(routeSurfaceProvider).login,
          );
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

  Future<void> _complete({required bool showHelpfulChoice}) async {
    if (_submitting) return;
    final bool canStartPlanner =
        showHelpfulChoice && widget.completedLocation == null;
    setState(() => _submitting = true);

    final accountScope = ref.read(accountStorageScopeProvider);
    final String? accountScopeId = accountScope.isWritable
        ? accountScope.v2Namespace
        : null;
    if (accountScopeId == null) {
      Logger.errorCategory(
        'onboarding',
        'Onboarding completion blocked because account storage is not ready.',
      );
      AppAnalytics.track(
        'onboarding_complete_failed',
        params: const <String, Object?>{
          'reason': 'account_storage_unavailable',
        },
      );
      _surfaceCompletionError();
      return;
    }

    try {
      SmartPlannerFirstValueRequest? firstValueRequest;
      if (canStartPlanner) {
        firstValueRequest = SmartPlannerFirstValueRequest(
          accountScopeId: accountScopeId,
          prompt: _helpCtrl.text.trim(),
          energy: _capacity,
          createdAt: DateTime.now().toUtc(),
        );
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingCompleteStorageKey, true);
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        OnboardingContentContract.currentVersion,
      );
      await ref.read(accountOnboardingCompleteProvider.notifier).complete();
      AppAnalytics.track(
        'onboarding_completed',
        params: <String, Object?>{
          'first_value_choice_requested': canStartPlanner,
          'optional_context_provided': _helpCtrl.text.trim().isNotEmpty,
          'optional_capacity_provided': _capacity != null,
          'protected_destination_preserved': widget.completedLocation != null,
        },
      );
      if (!mounted) return;

      ref.read(onboardingCompleteProvider.notifier).set(true);
      final routes = ref.read(routeSurfaceProvider);
      if (firstValueRequest != null) {
        ref
            .read(smartPlannerFirstValueProvider.notifier)
            .stage(firstValueRequest);
      }
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(
          widget.completedLocation ??
              (canStartPlanner ? routes.smartPlanner : routes.nexus),
        );
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
      _surfaceCompletionError();
    }
  }

  void _surfaceCompletionError() {
    if (!mounted) return;
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

  void _next() => unawaited(_completeWelcome());

  @override
  void dispose() {
    _page.dispose();
    _helpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final String continueToLogin = l10n.isSpanish
        ? 'CONTINUAR AL ACCESO'
        : 'CONTINUE TO LOGIN';
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
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgFirstSignal,
      overlayOpacity: 0.5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            PageView.builder(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: _totalPages,
              itemBuilder: (context, i) {
                if (i < slides.length) {
                  return _SlideView(
                    slide: slides[i],
                    footer: landscape
                        ? SizedBox(
                            width: 180,
                            child: _GradientButton(
                              label: continueToLogin,
                              onTap: _next,
                            ),
                          )
                        : null,
                  );
                }
                return _FirstValueSlide(
                  helpController: _helpCtrl,
                  selectedCapacity: _capacity,
                  submitting: _submitting,
                  preservesProtectedDestination:
                      widget.completedLocation != null,
                  onCapacityChanged: (double? value) {
                    setState(() => _capacity = value);
                  },
                  onShowChoice: () =>
                      unawaited(_complete(showHelpfulChoice: true)),
                  onSkip: () => unawaited(_complete(showHelpfulChoice: false)),
                );
              },
            ),

            // Bottom controls
            if (_current == 0 && !landscape)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      landscape ? 14 : 24,
                    ),
                    child: landscape
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 180,
                                child: _GradientButton(
                                  label: continueToLogin,
                                  onTap: _next,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Primary action button
                              _GradientButton(
                                label: continueToLogin,
                                onTap: _next,
                              ),
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
  });

  final IconData icon;
  final Color iconColor;
  final String tag;
  final String title;
  final String subtitle;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, this.footer});

  final _Slide slide;
  final Widget? footer;

  Widget _buildPulseAura(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Lottie.asset(
      AppAssets.animSignalPulse,
      width: width,
      height: height,
      animate: !reduceMotion,
      repeat: !reduceMotion,
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
                              _buildPulseAura(context, width: 86, height: 86),
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
                              letterSpacing: 0,
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
                              letterSpacing: 0,
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
                            letterSpacing: 0,
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
                        if (footer != null) ...[
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: footer,
                          ),
                        ],
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
                    _buildPulseAura(context, width: 66, height: 66),
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
                    letterSpacing: 0,
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
                    letterSpacing: 0,
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
                  letterSpacing: 0,
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
              if (footer != null) ...[
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerRight, child: footer),
              ],
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

class _FirstValueSlide extends StatelessWidget {
  const _FirstValueSlide({
    required this.helpController,
    required this.selectedCapacity,
    required this.submitting,
    required this.preservesProtectedDestination,
    required this.onCapacityChanged,
    required this.onShowChoice,
    required this.onSkip,
  });

  final TextEditingController helpController;
  final double? selectedCapacity;
  final bool submitting;
  final bool preservesProtectedDestination;
  final ValueChanged<double?> onCapacityChanged;
  final VoidCallback onShowChoice;
  final VoidCallback onSkip;

  String _copy(ChronoSparkLocalizations l10n, String english, String spanish) =>
      l10n.isSpanish ? spanish : english;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 760;
        return SafeArea(
          child: FocusTraversalGroup(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                wide ? 56 : 24,
                wide ? 48 : 28,
                wide ? 56 : 24,
                keyboardInset + 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        label: _copy(
                          l10n,
                          'First setup, step 3 of 3',
                          'Primera configuración, paso 3 de 3',
                        ),
                        excludeSemantics: true,
                        child: Text(
                          _copy(
                            l10n,
                            'FIRST SETUP 3 OF 3',
                            'CONFIGURACIÓN 3 DE 3',
                          ),
                          style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          preservesProtectedDestination
                              ? _copy(l10n, 'YOU\'RE READY', 'TODO LISTO')
                              : _copy(
                                  l10n,
                                  'WHAT WOULD HELP RIGHT NOW?',
                                  '¿QUÉ TE AYUDARÍA AHORA?',
                                ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: wide ? 38 : 30,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        preservesProtectedDestination
                            ? _copy(
                                l10n,
                                'Your requested page is ready. Continue without changing or creating anything.',
                                'La página que pediste está lista. Continúa sin cambiar ni crear nada.',
                              )
                            : _copy(
                                l10n,
                                'Share as much or as little as you want. ChronoSpark will offer one grounded choice before asking you to create anything.',
                                'Comparte lo que quieras. ChronoSpark ofrecerá una opción fundamentada antes de pedirte que crees algo.',
                              ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TemporalGlassSurface(
                        padding: EdgeInsets.all(wide ? 24 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (!preservesProtectedDestination) ...<Widget>[
                              Text(
                                _copy(
                                  l10n,
                                  'OPTIONAL QUESTION',
                                  'PREGUNTA OPCIONAL',
                                ),
                                style: const TextStyle(
                                  color: AppColors.neonCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('first-value-question'),
                                controller: helpController,
                                enabled: !submitting,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 600,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.45,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!submitting) onShowChoice();
                                },
                                decoration: InputDecoration(
                                  hintText: _copy(
                                    l10n,
                                    'For example: I feel overloaded and need one realistic next step.',
                                    'Por ejemplo: me siento saturado y necesito un próximo paso realista.',
                                  ),
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.black.withValues(
                                    alpha: 0.22,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                _copy(
                                  l10n,
                                  'CURRENT CAPACITY · OPTIONAL',
                                  'CAPACIDAD ACTUAL · OPCIONAL',
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  _capacityChoice(
                                    key: const Key('first-value-capacity-low'),
                                    label: _copy(l10n, 'Low', 'Baja'),
                                    value: .3,
                                  ),
                                  _capacityChoice(
                                    key: const Key(
                                      'first-value-capacity-steady',
                                    ),
                                    label: _copy(l10n, 'Steady', 'Estable'),
                                    value: .6,
                                  ),
                                  _capacityChoice(
                                    key: const Key('first-value-capacity-high'),
                                    label: _copy(l10n, 'High', 'Alta'),
                                    value: .85,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            Semantics(
                              container: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: AppColors.neonCyan,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _copy(
                                        l10n,
                                        preservesProtectedDestination
                                            ? 'Continuing preserves the page you requested. This setup step does not change or create anything.'
                                            : 'Your words and this check-in are used once and are not saved. A local decision receipt may record that guidance was shown or used. Nothing is created until you confirm it in Creator.',
                                        preservesProtectedDestination
                                            ? 'Continuar conserva la página que pediste. Este paso no cambia ni crea nada.'
                                            : 'Tus palabras y este registro se usan una vez y no se guardan. Un recibo local puede registrar que se mostró o usó la orientación. No se crea nada hasta que lo confirmes en Creador.',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('first-value-show-choice'),
                                onPressed: submitting ? null : onShowChoice,
                                icon: submitting
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        preservesProtectedDestination
                                            ? Icons.arrow_forward_rounded
                                            : Icons.auto_awesome_rounded,
                                      ),
                                label: Text(
                                  preservesProtectedDestination
                                      ? _copy(
                                          l10n,
                                          'CONTINUE TO REQUESTED PAGE',
                                          'CONTINUAR A LA PÁGINA PEDIDA',
                                        )
                                      : _copy(
                                          l10n,
                                          'SHOW ONE HELPFUL CHOICE',
                                          'MOSTRAR UNA OPCIÓN ÚTIL',
                                        ),
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: AppColors.neonCyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                key: const Key('first-value-skip'),
                                onPressed: submitting ? null : onSkip,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  foregroundColor: Colors.white70,
                                ),
                                child: Text(
                                  _copy(
                                    l10n,
                                    'SKIP FOR NOW',
                                    'SALTAR POR AHORA',
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _capacityChoice({
    required Key key,
    required String label,
    required double value,
  }) {
    final bool selected = selectedCapacity == value;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: submitting
          ? null
          : (bool isSelected) => onCapacityChanged(isSelected ? value : null),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selectedColor: AppColors.neonCyan.withValues(alpha: 0.28),
      side: BorderSide(color: selected ? AppColors.neonCyan : Colors.white24),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
