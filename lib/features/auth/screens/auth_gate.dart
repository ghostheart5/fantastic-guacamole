import 'package:fantastic_guacamole/core/utils/validators.dart';
import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Color _authBackgroundColor = Color(0xFF0C0812);

String friendlyAuthErrorMessage(String code, {String? rawMessage}) {
  final String backendMessage = rawMessage?.trim() ?? '';
  switch (code) {
    case 'invalid-email':
      return 'Invalid email format.';
    case 'user-not-found':
    case 'wrong-password':
      return 'Credentials are incorrect.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password is too weak.';
    case 'too-many-requests':
      return 'Rate limit engaged. Wait, then retry.';
    case 'network-request-failed':
      return 'Network link offline. Reconnect and retry.';
    case 'user-disabled':
      return 'Account access disabled. Contact support.';
    case 'user-token-expired':
    case 'invalid-user-token':
      return 'Session expired. Re-authenticate.';
    case 'requires-recent-login':
      return 'Re-authenticate to continue securely.';
    case 'google-sign-in-cancelled':
    case 'popup-closed-by-user':
      return 'Google sign-in canceled.';
    case 'no-current-user':
      return 'Session ended. Sign in again.';
    case 'auth-unavailable':
      return 'Auth backend unavailable in this runtime.';
    case 'operation-failed':
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Operation failed. Retry.';
    case 'operation-not-supported':
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'This operation is unavailable in the current build.';
    case 'missing-password':
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Password is required.';
    case 'missing-email':
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Account email is unavailable.';
    default:
      if (backendMessage.isNotEmpty) {
        return backendMessage;
      }
      return 'Authentication failed. Retry.';
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({
    required this.child,
    super.key,
    this.authService,
    this.startupError,
    this.enableMockLogin = !kReleaseMode,
    this.mockLoginEmail = '',
    this.mockLoginPassword = '',
  });

  final Widget child;
  final AuthServiceContract? authService;
  final String? startupError;
  final bool enableMockLogin;
  final String mockLoginEmail;
  final String mockLoginPassword;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final Future<void> _authReadyFuture;
  AuthServiceContract? _authService;
  String? _authInitError;
  bool _mockSessionActive = false;
  bool _authReadyTimedOut = false;

  @override
  void initState() {
    super.initState();
    _authReadyFuture = _initializeAuth().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _authReadyTimedOut = true;
        _authInitError = 'Authentication initialization timed out.';
        _authService ??= const _UnavailableAuthService();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStartupIssue =
        (widget.startupError?.trim().isNotEmpty ?? false);
    final bool allowMockAccess =
        widget.enableMockLogin ||
        (!kReleaseMode && (_authInitError != null || hasStartupIssue));
    final String? startupMessage = _effectiveStartupError;
    final AuthServiceContract fallbackAuthService =
        _authService ?? const _UnavailableAuthService();

    if (_mockSessionActive) {
      return widget.child;
    }

    return FutureBuilder<void>(
      future: _authReadyFuture,
      builder: (BuildContext context, AsyncSnapshot<void> authSnapshot) {
        if (authSnapshot.connectionState != ConnectionState.done) {
          if (allowMockAccess) {
            return _AuthScreen(
              authService: fallbackAuthService,
              startupError: startupMessage,
              enableMockLogin: true,
              mockLoginEmail: widget.mockLoginEmail,
              mockLoginPassword: widget.mockLoginPassword,
              onMockSignIn: _activateMockSession,
            );
          }
          return const Scaffold(
            backgroundColor: _authBackgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasError) {
          return const _AuthStatusMessage(
            title: 'Authentication unavailable',
            message:
                'Auth initialization failed. Please restart and try again.',
          );
        }

        final AuthServiceContract? authService = _authService;
        if (authService == null) {
          if (allowMockAccess) {
            return _AuthScreen(
              authService: fallbackAuthService,
              startupError: startupMessage,
              enableMockLogin: true,
              mockLoginEmail: widget.mockLoginEmail,
              mockLoginPassword: widget.mockLoginPassword,
              onMockSignIn: _activateMockSession,
            );
          }
          return _AuthStatusMessage(
            title: 'Authentication unavailable',
            message: _authReadyTimedOut
                ? 'Auth initialization timed out. Please retry.'
                : 'Auth service is not ready in this runtime.',
          );
        }

        if (_authInitError != null) {
          return _AuthScreen(
            authService: authService,
            startupError: startupMessage,
            enableMockLogin: allowMockAccess,
            mockLoginEmail: widget.mockLoginEmail,
            mockLoginPassword: widget.mockLoginPassword,
            onMockSignIn: _activateMockSession,
          );
        }

        return StreamBuilder<User?>(
          stream: authService.authStateChanges(),
          builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: _authBackgroundColor,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const _AuthStatusMessage(
                title: 'Authentication unavailable',
                message:
                    'Auth service reported an error. Please restart and try again.',
              );
            }

            final User? user = snapshot.data;
            if (startupMessage != null && startupMessage.trim().isNotEmpty) {
              return _AuthScreen(
                authService: authService,
                startupError: startupMessage,
                enableMockLogin: allowMockAccess,
                mockLoginEmail: widget.mockLoginEmail,
                mockLoginPassword: widget.mockLoginPassword,
                onMockSignIn: _activateMockSession,
              );
            }
            if (user == null) {
              return _AuthScreen(
                authService: authService,
                startupError: startupMessage,
                enableMockLogin: allowMockAccess,
                mockLoginEmail: widget.mockLoginEmail,
                mockLoginPassword: widget.mockLoginPassword,
                onMockSignIn: _activateMockSession,
              );
            }
            if (!user.emailVerified) {
              return _VerifyEmailScreen(
                authService: authService,
                email: user.email ?? '',
              );
            }
            return widget.child;
          },
        );
      },
    );
  }

  Future<void> _initializeAuth() async {
    if (widget.authService != null) {
      _authService = widget.authService;
      return;
    }

    if (widget.enableMockLogin) {
      _authService = const _UnavailableAuthService();
      return;
    }

    try {
      _authService = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(authServiceProvider);
    } catch (e) {
      _authInitError = 'Authentication backend unavailable for this runtime.';
      _authService = const _UnavailableAuthService();
    }
  }

  String? get _effectiveStartupError {
    final List<String> issues = <String>[];
    final String startupError = widget.startupError?.trim() ?? '';
    final String authInitError = _authInitError?.trim() ?? '';
    final bool productionReadinessBanner = startupError.startsWith(
      'Production readiness configuration is incomplete',
    );
    final bool crashlyticsOnly = startupError.contains(
      'Crashlytics is unavailable',
    );
    final bool hideStartupIssue =
        !kReleaseMode && (crashlyticsOnly || productionReadinessBanner);
    if (startupError.isNotEmpty && !hideStartupIssue) {
      issues.add(startupError);
    }
    final bool hideAuthBackendIssueForMockMode =
        widget.enableMockLogin &&
        authInitError.contains('Authentication backend unavailable');
    if (authInitError.isNotEmpty && !hideAuthBackendIssueForMockMode) {
      issues.add(authInitError);
    }
    if (issues.isEmpty) {
      return null;
    }
    return issues.join('\n');
  }

  void _activateMockSession() {
    if (_mockSessionActive || !mounted) {
      return;
    }
    ref.read(mockAuthSessionProvider.notifier).set(true);
    setState(() => _mockSessionActive = true);
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({
    required this.authService,
    required this.startupError,
    required this.enableMockLogin,
    required this.mockLoginEmail,
    required this.mockLoginPassword,
    required this.onMockSignIn,
  });

  final AuthServiceContract authService;
  final String? startupError;
  final bool enableMockLogin;
  final String mockLoginEmail;
  final String mockLoginPassword;
  final VoidCallback onMockSignIn;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscuredPassword = true;
  bool _signUpMode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscuredPassword,
      isSubmitting: _submitting,
      isSignUpMode: _signUpMode,
      allowSignUp: !widget.enableMockLogin,
      startupError: widget.startupError,
      showMockHint: widget.enableMockLogin,
      mockHint: widget.enableMockLogin
          ? 'Tester runtime detected. Use Tester Access to enter command mode.'
          : null,
      onTogglePassword: () {
        setState(() => _obscuredPassword = !_obscuredPassword);
      },
      onToggleMode: () {
        setState(() => _signUpMode = !_signUpMode);
      },
      onPrimaryAction: () => _runAuthAction(_handlePrimaryAction),
      onForgotPassword: () => _runAuthAction(_handleForgotPassword),
      onGoogleSignIn: () => _runAuthAction(_handleGoogleSignIn),
      onMockLogin: widget.enableMockLogin
          ? () => _runAuthAction(_handleMockSignIn)
          : null,
    );
  }

  Future<void> _handleMockSignIn() async {
    // Yield a frame before switching roots to keep tap handling responsive.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    widget.onMockSignIn();
  }

  Future<void> _handlePrimaryAction() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (!Validators.isValidEmail(email)) {
      _showMessage('Enter a valid email.');
      return;
    }

    if (password.trim().isEmpty) {
      _showMessage('Password required.');
      return;
    }

    if (_signUpMode) {
      if (!Validators.isStrongPassword(password)) {
        _showMessage('Use 8+ chars with upper, lower, and a number.');
        return;
      }
      await widget.authService.signUp(email: email, password: password);
      await widget.authService.sendEmailVerification();
      _showMessage('Verification link sent. Confirm inbox to proceed.');
      return;
    }

    await widget.authService.signIn(email: email, password: password);
  }

  Future<void> _handleForgotPassword() async {
    final String email = _emailController.text.trim();
    if (!Validators.isValidEmail(email)) {
      _showMessage('Enter account email, then trigger password reset.');
      return;
    }
    await widget.authService.sendPasswordReset(email);
    _showMessage('Password reset link sent.');
  }

  Future<void> _handleGoogleSignIn() async {
    if (widget.enableMockLogin) {
      widget.onMockSignIn();
      return;
    }
    await widget.authService.signInWithGoogle();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (_isSessionExpiredCode(e.code)) {
        await widget.authService.signOut();
      }
      _showMessage(friendlyAuthErrorMessage(e.code, rawMessage: e.message));
    } on Exception {
      _showMessage('Auth action failed. Retry.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isSessionExpiredCode(String code) {
    return code == 'user-token-expired' ||
        code == 'invalid-user-token' ||
        code == 'requires-recent-login' ||
        code == 'no-current-user';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnavailableAuthService implements AuthServiceContract {
  const _UnavailableAuthService();

  FirebaseAuthException _error() {
    return FirebaseAuthException(
      code: 'auth-unavailable',
      message: 'Authentication backend is unavailable.',
    );
  }

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    throw _error();
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    throw _error();
  }

  @override
  Future<User?> reloadCurrentUser() async {
    return null;
  }

  @override
  Future<void> sendEmailVerification() async {
    throw _error();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw _error();
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    throw _error();
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    throw _error();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    throw _error();
  }
}

class _VerifyEmailScreen extends StatefulWidget {
  const _VerifyEmailScreen({required this.authService, required this.email});

  final AuthServiceContract authService;
  final String email;

  @override
  State<_VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<_VerifyEmailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.mark_email_unread_outlined, size: 64),
                const SizedBox(height: 12),
                const Text('Verify email to unlock access'),
                const SizedBox(height: 8),
                Text(
                  widget.email.isEmpty
                      ? 'Open inbox and confirm account access.'
                      : widget.email,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _refreshVerification,
                  child: const Text('Verified · Continue'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _resendVerification,
                  child: const Text('Resend Verification Link'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.authService.signOut();
                        },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshVerification() async {
    setState(() => _busy = true);
    try {
      await widget.authService.reloadCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final String message =
          (e.code == 'user-token-expired' ||
              e.code == 'invalid-user-token' ||
              e.code == 'requires-recent-login')
          ? 'Session expired. Sign in again.'
          : 'Could not refresh account state.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _busy = true);
    try {
      await widget.authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link sent.')),
        );
      }
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification link.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _AuthStatusMessage extends StatelessWidget {
  const _AuthStatusMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
