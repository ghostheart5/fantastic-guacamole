import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
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
    this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    this.startupError,
    this.showMockHint = false,
    this.mockHint,
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
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final String? startupError;
  final bool showMockHint;
  final String? mockHint;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
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
    final VoidCallback? onMockLogin = widget.onMockLogin;
    final String? startupMessage =
        widget.startupError?.trim().isNotEmpty ?? false
        ? widget.startupError!.trim()
        : null;
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = size.width > size.height;
    final bool wideLayout = size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              AppAssets.bgLogin,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // Heavy dark overlay — bottom heavier for form readability
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.3, 0.65, 1.0],
                  colors: [
                    Color(0x66000000),
                    Color(0x88000000),
                    Color(0xCC0F172A),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),

          if (landscape && wideLayout)
            _LandscapeLoginContent(
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
              onMockLogin: onMockLogin,
              onToggleMode: widget.onToggleMode,
              onTogglePassword: widget.onTogglePassword,
              showMockHint: widget.showMockHint,
              mockHint: widget.mockHint,
            )
          else
            _PortraitLoginContent(
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
              onMockLogin: onMockLogin,
              onToggleMode: widget.onToggleMode,
              onTogglePassword: widget.onTogglePassword,
              showMockHint: widget.showMockHint,
              mockHint: widget.mockHint,
            ),

          // Loading indicator
          if (widget.isSubmitting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
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
        ],
      ),
    );
  }
}

class _PortraitLoginContent extends StatelessWidget {
  const _PortraitLoginContent({
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
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
  });

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
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LoginBrandHeader(pulse: pulse),
                  const SizedBox(height: 18),
                  _LoginFormCard(
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
                    onMockLogin: onMockLogin,
                    onToggleMode: onToggleMode,
                    onTogglePassword: onTogglePassword,
                    showMockHint: showMockHint,
                    mockHint: mockHint,
                    compactSecondaryButtons: false,
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
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
  });

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
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double leftWidth = math.min(constraints.maxWidth * 0.42, 420);
            final double rightWidth = constraints.maxWidth - leftWidth;
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
                      minHeight: constraints.maxHeight,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: leftWidth,
                          child: _LoginBrandPanel(pulse: pulse),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: rightWidth,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _LoginFormCard(
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

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
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
                'CHRONO\nSPARK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  height: 0.95,
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
        const SizedBox(height: 10),
        const Text(
          'TEMPORAL INTELLIGENCE SYSTEM',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 3.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF6C8CFF)],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
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
          'Access the system, reset the key, or initialize a new profile from one place.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.55),
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
    required this.onMockLogin,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.showMockHint,
    required this.mockHint,
    required this.compactSecondaryButtons,
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
  final VoidCallback? onMockLogin;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final bool showMockHint;
  final String? mockHint;
  final bool compactSecondaryButtons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSignUpMode ? 'CREATE ACCOUNT' : 'ACCESS SYSTEM',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (startupMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                startupMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD7D0),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 18),
          _PrimaryButton(
            label: isSignUpMode ? 'INITIALIZE PROFILE' : 'ENTER SYSTEM',
            isLoading: isSubmitting,
            onTap: onPrimaryAction,
          ),
          const SizedBox(height: 10),
          if (compactSecondaryButtons)
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Google',
                    icon: Icons.login_rounded,
                    color: AppColors.neonViolet,
                    onTap: onGoogleSignIn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondaryButton(
                    label: 'Reset Key',
                    icon: Icons.lock_reset_rounded,
                    color: AppColors.neonCyan,
                    onTap: onForgotPassword,
                  ),
                ),
                if (allowSignUp) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SecondaryButton(
                      label: isSignUpMode ? 'Log In' : 'Create',
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
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Google',
                        icon: Icons.login_rounded,
                        color: AppColors.neonViolet,
                        onTap: onGoogleSignIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Reset Key',
                        icon: Icons.lock_reset_rounded,
                        color: AppColors.neonCyan,
                        onTap: onForgotPassword,
                      ),
                    ),
                  ],
                ),
                if (allowSignUp) ...[
                  const SizedBox(height: 8),
                  _SecondaryButton(
                    label: isSignUpMode ? 'Log In' : 'Create',
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
              onTap: onMockLogin!,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFC857),
                  borderRadius: BorderRadius.circular(12),
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
                        'TESTER ACCESS  ·  COMMAND LOGIN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFDFA3),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.5,
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
              mockHint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE5C7A0),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
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
          Icon(icon, color: accentColor.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          ?trailing,
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
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.85), size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
