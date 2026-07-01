import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ui/layout/holo_background.dart';
import '../../../ui/widgets/panel_container.dart';
import '../../auth/auth_session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final AuthSessionController auth = context.read<AuthSessionController>();

    try {
      await auth.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Could not sign in.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final String defaultEmail = _emailController.text.trim();
    final TextEditingController resetController = TextEditingController(text: defaultEmail);

    final String? email = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('FORGOT PASSWORD'),
          content: TextField(
            controller: resetController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(resetController.text.trim()),
              child: const Text('SEND RESET LINK'),
            ),
          ],
        );
      },
    );

    resetController.dispose();
    if (email == null || email.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final AuthSessionController auth = context.read<AuthSessionController>();
    try {
      await auth.sendPasswordReset(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent to $email.')),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Could not send reset email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthSessionController auth = context.watch<AuthSessionController>();
    final bool showDemo = auth.allowDemoAuth;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: HoloBackground(
              backgroundAsset: 'assets/backgrounds/login_bg.png',
              child: SizedBox.shrink(),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: PanelContainer(
                  title: 'ChronoSpark Login',
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Sign in to continue.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                          ),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter an email address';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                          ),
                          validator: (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a password';
                            }
                            if (value.length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isSubmitting ? null : _forgotPassword,
                            child: const Text('FORGOT PASSWORD'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: Text(_isSubmitting ? 'SIGNING IN...' : 'SIGN IN'),
                        ),
                        if (showDemo) ...<Widget>[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _emailController.text = AuthSessionController.demoEmail;
                                      _passwordController.text = AuthSessionController.demoPassword;
                                    });
                                  },
                            child: const Text('Use demo credentials'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Demo: ${AuthSessionController.demoEmail} / ${AuthSessionController.demoPassword}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (auth.errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
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
