import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_controller.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';

class AuthShellScreen extends ConsumerStatefulWidget {
  const AuthShellScreen({super.key});

  @override
  ConsumerState<AuthShellScreen> createState() => _AuthShellScreenState();
}

class _AuthShellScreenState extends ConsumerState<AuthShellScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSignUpMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AuthController controller = ref.read(authControllerProvider.notifier);
    final bool isSubmitting = authState.isBusy;

    return LoginScreen(
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscurePassword,
      isSubmitting: isSubmitting,
      isSignUpMode: _isSignUpMode,
      allowSignUp: true,
      onPrimaryAction: () {
        if (_isSignUpMode) {
          controller.signUpWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } else {
          controller.signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
        }
      },
      onForgotPassword: () {
        controller.sendPasswordReset(_emailController.text);
      },
      onGoogleSignIn: controller.signInWithGoogle,
      onGitHubSignIn: controller.signInWithGitHub,
      onToggleMode: () {
        setState(() {
          _isSignUpMode = !_isSignUpMode;
        });
      },
      onTogglePassword: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      startupError: authState.failure?.message,
    );
  }
}
