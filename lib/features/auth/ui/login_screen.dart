import 'dart:math' as math;

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.isSignUpMode,
    this.allowSignUp = true,
    required this.onPrimaryAction,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onGitHubSignIn,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
    this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    this.startupError,
    this.showMockHint = false,
    this.mockHint,
    this.showFirstRunGuide = false,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final bool isSignUpMode;
  final bool allowSignUp;
  final VoidCallback onPrimaryAction;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGitHubSignIn;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final String? startupError;
  final bool showMockHint;
  final String? mockHint;
  final bool showFirstRunGuide;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _entry;
  final GlobalKey _loginFormKey = GlobalKey(debugLabel: 'first-login-form');
  bool _guideVisible = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pulse
        ..stop()
        ..value = 0;
      _entry
        ..stop()
        ..value = 1;
      return;
    }
    if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    if (_entry.value == 0 && !_entry.isAnimating) {
      _entry.forward();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final VoidCallback? onMockLogin = widget.onMockLogin;
    final String? startupError = widget.startupError;
    final String? startupMessage =
        startupError != null && startupError.trim().isNotEmpty
        ? startupError.trim()
        : null;
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = size.width > size.height;
    final bool wideLayout = size.width >= 900;
    final bool showFirstLoginGuide =
        _guideVisible && widget.showFirstRunGuide && !widget.isSubmitting;
    final Animation<double> brandAnimation = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
    );
    final Animation<double> formAnimation = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.18, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgLogin,
      overlayOpacity: 0.5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: <Widget>[
            if (landscape && wideLayout)
              _LandscapeLoginContent(
                formKey: _loginFormKey,
                pulse: _pulse,
                startupMessage: startupMessage,
                isSubmitting: widget.isSubmitting,
                isSignUpMode: widget.isSignUpMode,
                allowSignUp: widget.allowSignUp,
                emailController: widget.emailController,
                passwordController: widget.passwordController,
                obscurePassword: widget.obscurePassword,
                onPrimaryAction: widget.onPrimaryAction,
                onForgotPassword: widget.onForgotPassword,
                onGoogleSignIn: widget.onGoogleSignIn,
                onGitHubSignIn: widget.onGitHubSignIn,
                onPrivacyPolicy: widget.onPrivacyPolicy,
                onTermsOfService: widget.onTermsOfService,
                onMockLogin: onMockLogin,
                onToggleMode: widget.onToggleMode,
                onTogglePassword: widget.onTogglePassword,
                showMockHint: widget.showMockHint,
                mockHint: widget.mockHint,
                brandAnimation: brandAnimation,
                formAnimation: formAnimation,
              )
            else
              _PortraitLoginContent(
                formKey: _loginFormKey,
                pulse: _pulse,
                startupMessage: startupMessage,
                isSubmitting: widget.isSubmitting,
                isSignUpMode: widget.isSignUpMode,
                allowSignUp: widget.allowSignUp,
                emailController: widget.emailController,
                passwordController: widget.passwordController,
                obscurePassword: widget.obscurePassword,
                onPrimaryAction: widget.onPrimaryAction,
                onForgotPassword: widget.onForgotPassword,
                onGoogleSignIn: widget.onGoogleSignIn,
                onGitHubSignIn: widget.onGitHubSignIn,
                onPrivacyPolicy: widget.onPrivacyPolicy,
                onTermsOfService: widget.onTermsOfService,
                onMockLogin: onMockLogin,
                onToggleMode: widget.onToggleMode,
                onTogglePassword: widget.onTogglePassword,
                showMockHint: widget.showMockHint,
                mockHint: widget.mockHint,
                brandAnimation: brandAnimation,
                formAnimation: formAnimation,
              ),

            if (widget.isSubmitting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66050D1A),
                  child: Center(
                    child: TemporalGlassSurface(
                      padding: EdgeInsets.all(18),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showFirstLoginGuide)
              InteractiveTutorialOverlay(
                targetKey: _loginFormKey,
                stepLabel: l10n.isSpanish
                    ? 'Configuración 2 de 3'
                    : 'First setup 2 of 3',
                title: l10n.isSpanish
                    ? 'Inicia sesión o crea tu cuenta'
                    : 'Sign in or create your account',
                body: l10n.isSpanish
                    ? 'Usa la cuenta real que quieres que ChronoSpark recuerde. Después de autenticarte, continuarás con tu nombre visible.'
                    : 'Use the real account you want ChronoSpark to remember. After authentication, setup continues with your display name.',
                primaryLabel: l10n.isSpanish
                    ? 'Comenzar acceso'
                    : 'Start login',
                onPrimary: () => setState(() => _guideVisible = false),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortraitLoginContent extends StatelessWidget {
  const _PortraitLoginContent({
    required this.formKey,
    required this.pulse,
    required this.startupMessage,
    required this.isSubmitting,
    required this.isSignUpMode,
    required this.allowSignUp,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onPrimaryAction,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onGitHubSignIn,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
    required this.brandAnimation,
    required this.formAnimation,
  });

  final GlobalKey formKey;
  final AnimationController pulse;
  final String? startupMessage;
  final bool isSubmitting;
  final bool isSignUpMode;
  final bool allowSignUp;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onPrimaryAction;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGitHubSignIn;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;
  final Animation<double> brandAnimation;
  final Animation<double> formAnimation;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < Breakpoints.compact;
    return Positioned.fill(
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: IgnorePointer(
            ignoring: isSubmitting,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 20,
                compact ? 12 : 20,
                compact ? 14 : 20,
                compact ? 14 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StaggeredEntrance(
                    animation: brandAnimation,
                    offsetY: 18,
                    child: _LoginBrandHeader(pulse: pulse),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  _StaggeredEntrance(
                    animation: formAnimation,
                    offsetY: 24,
                    child: _LoginFormCard(
                      key: formKey,
                      startupMessage: startupMessage,
                      isSubmitting: isSubmitting,
                      isSignUpMode: isSignUpMode,
                      allowSignUp: allowSignUp,
                      emailController: emailController,
                      passwordController: passwordController,
                      obscurePassword: obscurePassword,
                      onPrimaryAction: onPrimaryAction,
                      onForgotPassword: onForgotPassword,
                      onGoogleSignIn: onGoogleSignIn,
                      onGitHubSignIn: onGitHubSignIn,
                      onPrivacyPolicy: onPrivacyPolicy,
                      onTermsOfService: onTermsOfService,
                      onMockLogin: onMockLogin,
                      onToggleMode: onToggleMode,
                      onTogglePassword: onTogglePassword,
                      showMockHint: showMockHint,
                      mockHint: mockHint,
                      compactSecondaryButtons: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeLoginContent extends StatelessWidget {
  const _LandscapeLoginContent({
    required this.formKey,
    required this.pulse,
    required this.startupMessage,
    required this.isSubmitting,
    required this.isSignUpMode,
    required this.allowSignUp,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onPrimaryAction,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onGitHubSignIn,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
    required this.brandAnimation,
    required this.formAnimation,
  });

  final GlobalKey formKey;
  final AnimationController pulse;
  final String? startupMessage;
  final bool isSubmitting;
  final bool isSignUpMode;
  final bool allowSignUp;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onPrimaryAction;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGitHubSignIn;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;
  final Animation<double> brandAnimation;
  final Animation<double> formAnimation;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double leftWidth = math.min(constraints.maxWidth * 0.42, 420);
            final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: IgnorePointer(
                ignoring: isSubmitting,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 40),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: leftWidth,
                          child: _StaggeredEntrance(
                            animation: brandAnimation,
                            offsetY: 10,
                            child: _LoginBrandPanel(pulse: pulse),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _StaggeredEntrance(
                                animation: formAnimation,
                                offsetY: 18,
                                child: _LoginFormCard(
                                  key: formKey,
                                  startupMessage: startupMessage,
                                  isSubmitting: isSubmitting,
                                  isSignUpMode: isSignUpMode,
                                  allowSignUp: allowSignUp,
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  obscurePassword: obscurePassword,
                                  onPrimaryAction: onPrimaryAction,
                                  onForgotPassword: onForgotPassword,
                                  onGoogleSignIn: onGoogleSignIn,
                                  onGitHubSignIn: onGitHubSignIn,
                                  onPrivacyPolicy: onPrivacyPolicy,
                                  onTermsOfService: onTermsOfService,
                                  onMockLogin: onMockLogin,
                                  onToggleMode: onToggleMode,
                                  onTogglePassword: onTogglePassword,
                                  showMockHint: showMockHint,
                                  mockHint: mockHint,
                                  compactSecondaryButtons: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.animation,
    required this.offsetY,
    required this.child,
  });

  final Animation<double> animation;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<Offset> slide = Tween<Offset>(
      begin: Offset(0, offsetY / 100),
      end: Offset.zero,
    ).animate(animation);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < Breakpoints.compact;
    final double titleSize = compact ? 34 : 42;
    final double subtitleSize = compact ? AppSizes.fontXs : AppSizes.fontSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final glowAlpha = 0.35 + 0.35 * math.sin(pulse.value * math.pi);
            return ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF6C8CFF)],
              ).createShader(bounds),
              child: Text(
                'CHRONOSPARK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: const Color(
                        0xFF00E5FF,
                      ).withValues(alpha: glowAlpha),
                      blurRadius: 28,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          'TEMPORAL INTELLIGENCE SYSTEM',
          style: TextStyle(
            color: Colors.white70,
            fontSize: subtitleSize,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        const SizedBox(width: 180, child: TemporalDivider()),
      ],
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LoginBrandHeader(pulse: pulse),
        const SizedBox(height: 18),
        const Text(
          'Your plans, signals, and history remain yours. Continue to your connected ChronoSpark workspace.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: AppSizes.fontLabel,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.startupMessage,
    required this.isSubmitting,
    required this.isSignUpMode,
    required this.allowSignUp,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onPrimaryAction,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onGitHubSignIn,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
    required this.compactSecondaryButtons,
    super.key,
  });

  final String? startupMessage;
  final bool isSubmitting;
  final bool isSignUpMode;
  final bool allowSignUp;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onPrimaryAction;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGitHubSignIn;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;
  final bool compactSecondaryButtons;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < Breakpoints.compact;
    final double edgePadding = compact ? 14 : 18;
    final double sectionGap = compact ? 10 : 14;
    final String startupText = startupMessage ?? '';
    final VoidCallback mockLoginTap = onMockLogin ?? () {};
    return TemporalGlassSurface(
      accent: isSignUpMode ? AppColors.neonViolet : AppColors.neonCyan,
      opacity: 0.92,
      padding: EdgeInsets.all(edgePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSignUpMode ? 'CREATE ACCOUNT' : 'ACCESS SYSTEM',
            style: TextStyle(
              color: isSignUpMode ? AppColors.neonViolet : AppColors.neonCyan,
              fontSize: compact ? AppSizes.fontXs : AppSizes.fontSm,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            isSignUpMode ? 'Create your workspace' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Secure access to your connected planning workspace.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: compact ? AppSizes.fontCaption : AppSizes.fontBody,
              height: 1.35,
            ),
          ),
          SizedBox(height: sectionGap),
          if (startupMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                startupText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD7D0),
                  fontSize: AppSizes.fontBody,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
          ],
          _NeonInput(
            key: const ValueKey('login-email-field'),
            controller: emailController,
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            hintText: 'Email address',
            obscure: false,
            accentColor: AppColors.neonCyan,
          ),
          SizedBox(height: compact ? 8 : 10),
          _NeonInput(
            key: const ValueKey('login-password-field'),
            controller: passwordController,
            icon: Icons.key_rounded,
            keyboardType: TextInputType.visiblePassword,
            hintText: 'Password',
            obscure: obscurePassword,
            accentColor: AppColors.neonViolet,
            trailing: SmartPressable(
              onTap: onTogglePassword,
              child: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.neonViolet.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          SizedBox(
            height: AppSizes.touchTarget,
            child: Align(
              alignment: Alignment.centerRight,
              child: SmartPressable(
                onTap: onForgotPassword,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.neonCyan.withValues(alpha: 0.9),
                      fontSize: AppSizes.fontBody,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          _LoginLegalActions(
            onPrivacyPolicy: onPrivacyPolicy,
            onTermsOfService: onTermsOfService,
          ),
          SizedBox(height: compact ? 10 : 14),
          _PrimaryButton(
            label: isSignUpMode ? 'INITIALIZE PROFILE' : 'ENTER SYSTEM',
            isLoading: isSubmitting,
            onTap: onPrimaryAction,
          ),
          if (!showMockHint) ...[
            SizedBox(height: compact ? 12 : 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.18)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.18)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SecondaryButton(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata_rounded,
              color: Colors.white,
              leading: const _GoogleGlyph(size: 18),
              onTap: onGoogleSignIn,
            ),
            const SizedBox(height: 8),
            _SecondaryButton(
              label: 'Continue with GitHub',
              icon: Icons.code_rounded,
              color: Colors.white,
              leading: const _GitHubGlyph(size: 16),
              onTap: onGitHubSignIn,
            ),
          ],
          SizedBox(height: compact ? 6 : 8),
          if (compactSecondaryButtons)
            Row(
              children: [
                if (allowSignUp) ...[
                  const SizedBox(width: 0),
                  Expanded(
                    child: _SecondaryButton(
                      label: isSignUpMode
                          ? 'Switch to Login'
                          : 'Create Account',
                      icon: isSignUpMode
                          ? Icons.arrow_back_rounded
                          : Icons.person_add_rounded,
                      color: AppColors.primary,
                      onTap: onToggleMode,
                    ),
                  ),
                ],
              ],
            )
          else
            Column(
              children: [
                if (allowSignUp) ...[
                  const SizedBox(height: 2),
                  _SecondaryButton(
                    label: isSignUpMode ? 'Switch to Login' : 'Create Account',
                    icon: isSignUpMode
                        ? Icons.arrow_back_rounded
                        : Icons.person_add_rounded,
                    color: AppColors.primary,
                    onTap: onToggleMode,
                  ),
                ],
              ],
            ),
          if (showMockHint && onMockLogin != null) ...[
            const SizedBox(height: 10),
            SmartPressable(
              key: const ValueKey<String>('qa-tester-access-button'),
              onTap: mockLoginTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFC857),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x99FFC857)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Color(0xFFFFC857),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TESTER ACCESS  ·  TEST LOGIN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFDFA3),
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.fontCaption,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (showMockHint && (mockHint?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              mockHint ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE5C7A0),
                fontSize: AppSizes.fontCaption,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginLegalActions extends StatelessWidget {
  const _LoginLegalActions({
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
  });

  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfService;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return SizedBox(
      height: AppSizes.touchTarget,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _LoginLegalAction(
              key: const ValueKey<String>('login-privacy-action'),
              label: l10n.isSpanish ? 'Privacidad' : 'Privacy',
              semanticLabel: l10n.isSpanish
                  ? 'Abrir política de privacidad'
                  : 'Open Privacy Policy',
              icon: Icons.privacy_tip_outlined,
              onTap: onPrivacyPolicy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LoginLegalAction(
              key: const ValueKey<String>('login-terms-action'),
              label: l10n.isSpanish ? 'Términos' : 'Terms',
              semanticLabel: l10n.isSpanish
                  ? 'Abrir términos del servicio'
                  : 'Open Terms of Service',
              icon: Icons.description_outlined,
              onTap: onTermsOfService,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLegalAction extends StatelessWidget {
  const _LoginLegalAction({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 17, color: AppColors.neonCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontCaption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonInput extends StatelessWidget {
  const _NeonInput({
    super.key,
    required this.controller,
    required this.icon,
    required this.keyboardType,
    this.hintText,
    required this.obscure,
    required this.accentColor,
    this.trailing,
  });

  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final String? hintText;
  final bool obscure;
  final Color accentColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: accentColor.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontLabel,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: AppSizes.fontLabel,
                ),
              ),
            ),
          ),
          if (trailing case final Widget value)
            SizedBox.square(
              dimension: AppSizes.touchTarget,
              child: Center(child: value),
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF6C8CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: AppSizes.fontBodyLg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.color,
    this.leading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isGoogleAction =
        color == Colors.white || label.toLowerCase().contains('google');
    return SmartPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isGoogleAction
              ? Colors.white.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.08),
          border: Border.all(
            color: isGoogleAction
                ? Colors.white.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isGoogleAction
                  ? Colors.white.withValues(alpha: 0.08)
                  : color.withValues(alpha: 0.12),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading ??
                Icon(
                  icon,
                  color: isGoogleAction
                      ? Colors.white.withValues(alpha: 0.92)
                      : color.withValues(alpha: 0.9),
                  size: 18,
                ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => const SweepGradient(
        colors: <Color>[
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
      ).createShader(bounds),
      child: Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GitHubGlyph extends StatelessWidget {
  const _GitHubGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'GH',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.7,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}
