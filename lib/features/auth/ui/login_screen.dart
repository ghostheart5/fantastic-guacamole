import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
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

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final VoidCallback? onMockLogin = widget.onMockLogin;
    final String? startupMessage =
        widget.startupError?.trim().isNotEmpty ?? false
        ? widget.startupError!.trim()
        : null;
    return Scaffold(
      backgroundColor: const Color(0xFF080506),
      body: SafeArea(
        child: IgnorePointer(
          ignoring: widget.isSubmitting,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.bgLogin,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xAA130B0B), Color(0xE6080506)],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.isSignUpMode ? 'Create account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.isSignUpMode
                            ? 'Set up your ChronoSpark profile to get started.'
                            : 'Sign in to continue your session.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF0C9B2),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if (startupMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            startupMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD7D0),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _GlyphInput(
                        key: const ValueKey('login-email-field'),
                        controller: widget.emailController,
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'Email address',
                        obscure: false,
                      ),
                      const SizedBox(height: 8),
                      _GlyphInput(
                        key: const ValueKey('login-password-field'),
                        controller: widget.passwordController,
                        icon: Icons.key_rounded,
                        keyboardType: TextInputType.visiblePassword,
                        hintText: 'Password',
                        obscure: widget.obscurePassword,
                        trailing: SmartPressable(
                          onTap: widget.onTogglePassword,
                          child: Icon(
                            widget.obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: const Color(0xFFE04D2D),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _OrbAction(
                            label: widget.isSignUpMode ? 'Create' : 'Sign in',
                            icon: widget.isSignUpMode
                                ? Icons.person_add_alt_rounded
                                : Icons.arrow_forward_rounded,
                            color: AppColors.recallRed,
                            onTap: widget.onPrimaryAction,
                          ),
                          _OrbAction(
                            label: 'Google',
                            icon: Icons.login_rounded,
                            color: AppColors.neonViolet,
                            onTap: widget.onGoogleSignIn,
                          ),
                          _OrbAction(
                            label: 'Reset',
                            icon: Icons.restart_alt_rounded,
                            color: AppColors.neonCyan,
                            onTap: widget.onForgotPassword,
                          ),
                          if (widget.allowSignUp)
                            _OrbAction(
                              label: widget.isSignUpMode
                                  ? 'Switch to sign in'
                                  : 'Switch to sign up',
                              icon: Icons.swap_horiz_rounded,
                              color: const Color(0xFFFF8844),
                              onTap: widget.onToggleMode,
                            ),
                        ],
                      ),
                      if (widget.showMockHint && onMockLogin != null) ...[
                        const SizedBox(height: 10),
                        SmartPressable(
                          onTap: onMockLogin,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x2EE39A2B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xCCF2B24A),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                  color: Color(0xFFFFC96A),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tester Access (Mock Login)',
                                  style: TextStyle(
                                    color: Color(0xFFFFDFA3),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (widget.showMockHint &&
                          (widget.mockHint?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.mockHint!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE5C7A0),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.isSubmitting)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF5530),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphInput extends StatelessWidget {
  const _GlyphInput({
    super.key,
    required this.controller,
    required this.icon,
    required this.keyboardType,
    this.hintText,
    required this.obscure,
    this.trailing,
  });

  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final String? hintText;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x6E170C0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99F05A36)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x332E0909), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF35D35), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0x99F7C9B8),
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

class _OrbAction extends StatelessWidget {
  const _OrbAction({
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
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              color.withValues(alpha: 0.34),
              color.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.78)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.95), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
