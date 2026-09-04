import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/utils/validators.dart';
import 'package:fantastic_guacamole/domain/models/deep_link_mode.dart';
import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/onboarding_preferences_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

bool _isNewUserDatabaseSaveFailure(String message) {
  final String normalized = message.toLowerCase();
  return normalized.contains('database error saving new user') ||
      (normalized.contains('unexpected') &&
          normalized.contains('failure') &&
          normalized.contains('new user'));
}

String friendlyAuthErrorMessage(String code, {String? rawMessage}) {
  final String backendMessage = rawMessage?.trim() ?? '';
  if (_isNewUserDatabaseSaveFailure(backendMessage)) {
    return 'Sign-up is temporarily unavailable. Please retry in a moment.';
  }
  switch (code) {
    case 'invalid-email':
      return 'Invalid email format.';
    case 'user-not-found':
    case 'wrong-password':
      return 'Credentials are incorrect.';
    case 'email-already-in-use':
      return 'Unable to create an account with these details.';
    case 'weak-password':
      return 'Password is too weak.';
    case 'too-many-requests':
      return 'Rate limit engaged. Wait, then retry.';
    case 'push-token-isolation-failed':
      return 'Sign-out was paused to protect notification privacy. Reconnect and retry.';
    case 'network-request-failed':
      return 'Network link offline. Reconnect and retry.';
    case 'user-disabled':
      return 'Account access disabled. Contact support.';
    case 'user-token-expired':
    case 'invalid-user-token':
      return 'Sign-in expired. Local work is safe and cloud sync is paused. Sign in again to resume.';
    case 'requires-recent-login':
      return 'Re-authenticate to continue securely.';
    case 'google-sign-in-cancelled':
    case 'popup-closed-by-user':
      return 'Google sign-in canceled.';
    case 'github-sign-in-cancelled':
      return 'GitHub sign-in canceled.';
    case 'no-current-user':
      return 'You were signed out. Local work remains on this device; sign in again to resume account features.';
    case 'auth-unavailable':
      return 'Sign-in services are temporarily unavailable. Your local work is safe; retry when connected.';
    case 'operation-failed':
      return 'The account operation could not be completed. Retry or contact support if it continues.';
    case 'operation-not-supported':
      return 'This account operation is unavailable right now. Contact support for help.';
    case 'missing-password':
      return 'Enter your password to continue.';
    case 'missing-email':
      return 'Your account email could not be confirmed. Sign in again.';
    default:
      return 'Authentication failed. Retry.';
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({
    required this.child,
    super.key,
    this.authService,
    this.startupError,
    this.deepLinkMode,
    this.onboardingLocation,
    this.enableMockLogin = false,
    this.initializeBackend,
  });

  final Widget child;
  final AuthServiceContract? authService;
  final String? startupError;
  final DeepLinkMode? deepLinkMode;
  final String? onboardingLocation;
  final bool enableMockLogin;
  final Future<String?> Function()? initializeBackend;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late Future<void> _authReadyFuture;
  late final AuthRuntimeCoordinator _authRuntime;
  Future<void>? _authInitializationSource;
  AuthServiceContract? _authService;
  String? _authInitError;
  bool _authReadyTimedOut = false;
  bool _authRetryReady = true;

  @override
  void initState() {
    super.initState();
    _authRuntime = ref.read(authRuntimeCoordinatorProvider);
    _startAuthInitialization();
  }

  void _startAuthInitialization() {
    final Future<void> source = _initializeAuth();
    _authInitializationSource = source;
    _authRetryReady = false;
    _authReadyFuture = source.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _authReadyTimedOut = true;
        _authInitError = 'Authentication initialization timed out.';
        _authService ??= _authRuntime.unavailableService;
      },
    );
    unawaited(
      source.whenComplete(() {
        if (!mounted || !identical(_authInitializationSource, source)) {
          return;
        }
        setState(() {
          _authRetryReady = true;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allowMockAccess = widget.enableMockLogin;
    final String? startupMessage = _effectiveStartupError;
    final String onboardingLocation =
        widget.onboardingLocation ?? ref.read(routeSurfaceProvider).onboarding;
    final AuthServiceContract fallbackAuthService =
        _authService ?? _authRuntime.unavailableService;
    final AccountStorageScope accountScope = ref.watch(
      accountStorageScopeProvider,
    );
    final bool mockSignInActive = ref.watch(mockSignInProvider);
    final String qaAccountId = ref.watch(qaMockAccountIdProvider);

    if (mockSignInActive) {
      return _scopeIsReadyFor(accountScope, qaAccountId)
          ? widget.child
          : const _AuthLoadingShell();
    }

    return FutureBuilder<void>(
      future: _authReadyFuture,
      builder: (BuildContext context, AsyncSnapshot<void> authSnapshot) {
        if (authSnapshot.connectionState != ConnectionState.done) {
          if (allowMockAccess) {
            return _AuthScreen(
              authService: fallbackAuthService,
              startupError: startupMessage,
              deepLinkMode: widget.deepLinkMode,
              onboardingLocation: onboardingLocation,
              enableMockLogin: true,
              onMockSignIn: _activatePrimaryMockSignIn,
              onSecondaryMockSignIn: _activateSecondaryMockSignIn,
            );
          }
          return const _AuthLoadingShell();
        }

        if (authSnapshot.hasError) {
          return _AuthStatusMessage(
            title: 'Authentication unavailable',
            message: 'Auth initialization failed. Retry when ready.',
            onRetry: _retryAuthInitialization,
            retryEnabled: _authRetryReady,
          );
        }

        final AuthServiceContract? authService = _authService;
        if (authService == null) {
          if (allowMockAccess) {
            return _AuthScreen(
              authService: fallbackAuthService,
              startupError: startupMessage,
              deepLinkMode: widget.deepLinkMode,
              onboardingLocation: onboardingLocation,
              enableMockLogin: true,
              onMockSignIn: _activatePrimaryMockSignIn,
              onSecondaryMockSignIn: _activateSecondaryMockSignIn,
            );
          }
          return _AuthStatusMessage(
            title: 'Authentication unavailable',
            message: _authReadyTimedOut
                ? 'Auth initialization timed out. Please retry.'
                : 'Auth service is not ready in this runtime.',
            onRetry: _retryAuthInitialization,
            retryEnabled: _authRetryReady,
          );
        }

        if (_authInitError != null && !allowMockAccess) {
          return _AuthStatusMessage(
            title: 'Sign-in services unavailable',
            message: _authInitError!,
            onRetry: _retryAuthInitialization,
            retryEnabled: _authRetryReady,
          );
        }

        return StreamBuilder<User?>(
          stream: authService.authStateChanges(),
          builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              if (allowMockAccess) {
                return _AuthScreen(
                  authService: authService,
                  startupError: startupMessage,
                  deepLinkMode: widget.deepLinkMode,
                  onboardingLocation: onboardingLocation,
                  enableMockLogin: true,
                  onMockSignIn: _activatePrimaryMockSignIn,
                  onSecondaryMockSignIn: _activateSecondaryMockSignIn,
                );
              }
              return const _AuthLoadingShell();
            }
            if (snapshot.hasError) {
              return _AuthStatusMessage(
                title: 'Authentication unavailable',
                message:
                    'Auth service reported an error. Retry the connection.',
                onRetry: _retryAuthInitialization,
                retryEnabled: true,
              );
            }

            final User? user = snapshot.data;
            if (startupMessage != null && startupMessage.trim().isNotEmpty) {
              return _AuthScreen(
                authService: authService,
                startupError: startupMessage,
                deepLinkMode: widget.deepLinkMode,
                onboardingLocation: onboardingLocation,
                enableMockLogin: allowMockAccess,
                onMockSignIn: _activatePrimaryMockSignIn,
                onSecondaryMockSignIn: _activateSecondaryMockSignIn,
              );
            }
            if (user == null) {
              return _AuthScreen(
                authService: authService,
                startupError: startupMessage,
                deepLinkMode: widget.deepLinkMode,
                onboardingLocation: onboardingLocation,
                enableMockLogin: allowMockAccess,
                onMockSignIn: _activatePrimaryMockSignIn,
                onSecondaryMockSignIn: _activateSecondaryMockSignIn,
              );
            }
            if (!user.emailVerified) {
              return _VerifyEmailScreen(
                authService: authService,
                email: user.email ?? '',
              );
            }
            return _scopeIsReadyFor(accountScope, user.id)
                ? widget.child
                : const _AuthLoadingShell();
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
      _authService = _authRuntime.unavailableService;
      return;
    }

    try {
      final bool supabaseConfigured = ref
          .read(intelligenceStateProvider)
          .environment
          .isSupabaseConfigured;
      const int maxInitAttempts = 3;

      for (int attempt = 0; attempt < maxInitAttempts; attempt++) {
        final String? backendIssue =
            await (widget.initializeBackend?.call() ??
                _authRuntime.initializeBackend(
                  isMockMode: ref
                      .read(intelligenceStateProvider)
                      .flags
                      .mockMode,
                ));
        if (backendIssue != null) {
          final bool shouldRetry = attempt < maxInitAttempts - 1;
          if (shouldRetry) {
            await Future<void>.delayed(const Duration(milliseconds: 350));
            continue;
          }
          _authInitError = backendIssue;
          _authService = _authRuntime.unavailableService;
          return;
        }
        if (attempt > 0) {
          // Force the provider-owned runtime dependencies to rebuild. Without
          // invalidating them, a retry would return the same cached service
          // created before backend initialization completed.
          _authRuntime.refreshService();
        }
        final AuthServiceContract authService = _authRuntime.readService();
        _authService = authService;

        final bool backendUnavailable = _authRuntime.isUnavailable(authService);
        final bool shouldRetry =
            supabaseConfigured &&
            backendUnavailable &&
            attempt < maxInitAttempts - 1;
        if (!shouldRetry) {
          if (supabaseConfigured && backendUnavailable) {
            _authInitError =
                'Authentication backend is configured but unavailable in this runtime.';
          }
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      _authInitError = 'Authentication backend unavailable for this runtime.';
      _authService = _authRuntime.unavailableService;
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

  void _retryAuthInitialization() {
    if (!_authRetryReady) {
      return;
    }
    setState(() {
      _authService = null;
      _authInitError = null;
      _authReadyTimedOut = false;
      _startAuthInitialization();
    });
  }

  void _activatePrimaryMockSignIn() {
    _activateMockSignIn(primaryQaAccountId);
  }

  void _activateSecondaryMockSignIn() {
    _activateMockSignIn(secondaryQaAccountId);
  }

  void _activateMockSignIn(String accountId) {
    if (ref.read(mockSignInProvider) || !mounted) {
      return;
    }
    ref.read(qaMockAccountIdProvider.notifier).select(accountId);
    ref.read(mockSignInProvider.notifier).set(true);
  }
}

bool _scopeIsReadyFor(AccountStorageScope scope, String userId) {
  return scope.isWritable && scope.rawUserId == userId;
}

class _AuthScreen extends ConsumerStatefulWidget {
  const _AuthScreen({
    required this.authService,
    required this.startupError,
    required this.deepLinkMode,
    required this.onboardingLocation,
    required this.enableMockLogin,
    required this.onMockSignIn,
    required this.onSecondaryMockSignIn,
  });

  final AuthServiceContract authService;
  final String? startupError;
  final DeepLinkMode? deepLinkMode;
  final String onboardingLocation;
  final bool enableMockLogin;
  final VoidCallback onMockSignIn;
  final VoidCallback onSecondaryMockSignIn;

  @override
  ConsumerState<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<_AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryPasswordController =
      TextEditingController();
  final TextEditingController _recoveryConfirmController =
      TextEditingController();
  bool _obscuredPassword = true;
  bool _obscuredRecoveryPassword = true;
  bool _obscuredRecoveryConfirm = true;
  bool _signUpMode = false;
  bool _submitting = false;
  bool _dismissRecoveryMode = false;
  bool _returningToWelcome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLinkModeHint());
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryPasswordController.dispose();
    _recoveryConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool inRecoveryMode =
        widget.deepLinkMode == DeepLinkMode.recovery && !_dismissRecoveryMode;
    if (inRecoveryMode) {
      return _buildRecoveryScreen(context);
    }

    final bool canReturnToWelcome =
        ref.watch(onboardingWelcomeCompleteProvider) &&
        !ref.watch(onboardingCompleteProvider);

    return PopScope<Object?>(
      canPop: !canReturnToWelcome,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && canReturnToWelcome) {
          unawaited(_returnToWelcome());
        }
      },
      child: LoginScreen(
        emailController: _emailController,
        passwordController: _passwordController,
        obscurePassword: _obscuredPassword,
        isSubmitting: _submitting,
        isSignUpMode: _signUpMode,
        allowSignUp: !widget.enableMockLogin,
        startupError: widget.startupError,
        showMockHint: widget.enableMockLogin,
        mockHint: widget.enableMockLogin
            ? 'QA tester build uses an isolated local test profile.'
            : null,
        showFirstRunGuide: canReturnToWelcome,
        onTogglePassword: () {
          setState(() => _obscuredPassword = !_obscuredPassword);
        },
        onToggleMode: () {
          setState(() => _signUpMode = !_signUpMode);
        },
        onPrimaryAction: () => _runAuthAction(_handlePrimaryAction),
        onForgotPassword: () => _runAuthAction(_handleForgotPassword),
        onGoogleSignIn: () => _runAuthAction(_handleGoogleSignIn),
        onGitHubSignIn: () => _runAuthAction(_handleGitHubSignIn),
        onPrivacyPolicy: () =>
            context.push(ref.read(routeSurfaceProvider).privacy),
        onTermsOfService: () =>
            context.push(ref.read(routeSurfaceProvider).terms),
        onMockLogin: widget.enableMockLogin
            ? () => _runAuthAction(_handleMockSignIn)
            : null,
        onSecondaryMockLogin: widget.enableMockLogin
            ? () => _runAuthAction(_handleSecondaryMockSignIn)
            : null,
      ),
    );
  }

  Future<void> _returnToWelcome() async {
    if (_returningToWelcome) {
      return;
    }
    _returningToWelcome = true;
    final GoRouter? router = GoRouter.maybeOf(context);
    try {
      await ref.read(onboardingPreferencesRepositoryProvider).resetWelcome();
      if (!mounted) {
        return;
      }
      ref.read(onboardingWelcomeCompleteProvider.notifier).set(false);
      if (router != null) {
        context.go(widget.onboardingLocation);
      }
    } finally {
      _returningToWelcome = false;
    }
  }

  Future<void> _applyDeepLinkModeHint() async {
    final DeepLinkMode? mode = widget.deepLinkMode;
    if (mode == null) {
      return;
    }

    if (mode == DeepLinkMode.recovery) {
      _showMessage(
        'Password reset link received. Set your new password below.',
      );
      return;
    }

    if (mode == DeepLinkMode.verifyEmail) {
      try {
        await widget.authService.reloadCurrentUser();
      } catch (_) {
        // Ignore callback refresh failures and keep login available.
      }
      _showMessage(
        'Email verification callback received. Continue sign-in if needed.',
      );
      return;
    }

    if (mode == DeepLinkMode.authCallback) {
      _showMessage(
        'Authentication callback received. Continuing sign-in flow.',
      );
    }
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
      AppAnalytics.track(
        'login_event',
        params: <String, Object?>{'provider': 'email', 'mode': 'signup'},
      );
      _showMessage('Verification link sent. Confirm inbox to proceed.');
      return;
    }

    await widget.authService.signIn(email: email, password: password);
    AppAnalytics.track(
      'login_event',
      params: <String, Object?>{'provider': 'email', 'mode': 'signin'},
    );
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

  Future<void> _handleMockSignIn() async {
    if (!widget.enableMockLogin) {
      return;
    }
    AppAnalytics.track(
      'login_event',
      params: <String, Object?>{'provider': 'mock', 'mode': 'tester_access'},
    );
    widget.onMockSignIn();
  }

  Future<void> _handleSecondaryMockSignIn() async {
    if (!widget.enableMockLogin) {
      return;
    }
    AppAnalytics.track(
      'login_event',
      params: <String, Object?>{
        'provider': 'mock',
        'mode': 'tester_access_secondary',
      },
    );
    widget.onSecondaryMockSignIn();
  }

  Future<void> _handleGoogleSignIn() async {
    if (widget.enableMockLogin) {
      await _handleMockSignIn();
      return;
    }
    await widget.authService.signInWithGoogle();
    AppAnalytics.track(
      'login_event',
      params: <String, Object?>{'provider': 'google', 'mode': 'signin'},
    );
  }

  Future<void> _handleGitHubSignIn() async {
    if (widget.enableMockLogin) {
      await _handleMockSignIn();
      return;
    }
    await widget.authService.signInWithGitHub();
    AppAnalytics.track(
      'login_event',
      params: <String, Object?>{'provider': 'github', 'mode': 'signin'},
    );
  }

  Future<void> _handleRecoveryUpdatePassword() async {
    final String password = _recoveryPasswordController.text;
    final String confirm = _recoveryConfirmController.text;

    if (!Validators.isStrongPassword(password)) {
      _showMessage('Use 8+ chars with upper, lower, and a number.');
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match.');
      return;
    }

    await widget.authService.updatePassword(newPassword: password);
    final User? refreshedUser = await widget.authService.reloadCurrentUser();
    if (!mounted) {
      return;
    }
    if (refreshedUser != null) {
      _showMessage('Password updated. Redirecting to your workspace...');
      return;
    }
    setState(() => _dismissRecoveryMode = true);
    _showMessage('Password updated. Sign in with your new password.');
  }

  Widget _buildRecoveryScreen(BuildContext context) {
    return _AuthGlassShell(
      backgroundAssetPath: AppAssets.bgTemporalRecovery,
      maxWidth: 620,
      child: TemporalGlassSurface(
        accent: AppColors.neonCyan,
        opacity: 0.94,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TemporalStatusRow(
              icon: Icons.link_rounded,
              text: 'Recovery link accepted',
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 18),
            const Text(
              'ACCOUNT RECOVERY',
              style: TextStyle(
                color: AppColors.neonViolet,
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a new password',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a new strong password for your ChronoSpark account.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _recoveryPasswordController,
              obscureText: _obscuredRecoveryPassword,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, letterSpacing: 0),
              decoration: _authFieldDecoration(
                label: 'New Password',
                icon: Icons.key_rounded,
                accent: AppColors.neonCyan,
                trailing: IconButton(
                  tooltip: _obscuredRecoveryPassword
                      ? 'Show password'
                      : 'Hide password',
                  constraints: const BoxConstraints.tightFor(
                    width: AppSizes.touchTarget,
                    height: AppSizes.touchTarget,
                  ),
                  onPressed: () => setState(
                    () =>
                        _obscuredRecoveryPassword = !_obscuredRecoveryPassword,
                  ),
                  icon: Icon(
                    _obscuredRecoveryPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _recoveryConfirmController,
              obscureText: _obscuredRecoveryConfirm,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, letterSpacing: 0),
              decoration: _authFieldDecoration(
                label: 'Confirm Password',
                icon: Icons.key_rounded,
                accent: AppColors.neonViolet,
                trailing: IconButton(
                  tooltip: _obscuredRecoveryConfirm
                      ? 'Show password confirmation'
                      : 'Hide password confirmation',
                  constraints: const BoxConstraints.tightFor(
                    width: AppSizes.touchTarget,
                    height: AppSizes.touchTarget,
                  ),
                  onPressed: () => setState(
                    () => _obscuredRecoveryConfirm = !_obscuredRecoveryConfirm,
                  ),
                  icon: Icon(
                    _obscuredRecoveryConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const TemporalDivider(color: AppColors.neonViolet),
            const SizedBox(height: 18),
            TemporalActionButton(
              label: 'Update Password',
              icon: Icons.verified_user_outlined,
              onPressed: _submitting
                  ? null
                  : () => _runAuthAction(_handleRecoveryUpdatePassword),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neonCyan,
                  minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitting
                    ? null
                    : () => setState(() => _dismissRecoveryMode = true),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Sign In'),
              ),
            ),
            const SizedBox(height: 8),
            const TemporalStatusRow(
              icon: Icons.shield_outlined,
              text:
                  'ChronoSpark never displays or stores your password in readable form.',
            ),
          ],
        ),
      ),
    );
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
    final String email = widget.email.trim();
    return _AuthGlassShell(
      backgroundAssetPath: AppAssets.bgArrival,
      maxWidth: 580,
      child: TemporalGlassSurface(
        accent: AppColors.neonViolet,
        opacity: 0.94,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 48,
              color: AppColors.neonCyan,
            ),
            const SizedBox(height: 18),
            const Text(
              'ACCOUNT VERIFICATION',
              style: TextStyle(
                color: AppColors.neonViolet,
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verify email to unlock access',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Open the verification link in your inbox, then return here to continue securely.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            if (email.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.alternate_email_rounded,
                        color: AppColors.neonCyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const TemporalDivider(color: AppColors.neonViolet),
            const SizedBox(height: 18),
            TemporalActionButton(
              label: 'Verified · Continue',
              icon: Icons.verified_outlined,
              onPressed: _busy ? null : _refreshVerification,
            ),
            const SizedBox(height: 10),
            TemporalActionButton(
              label: 'Resend Verification Link',
              icon: Icons.outgoing_mail,
              filled: false,
              accent: AppColors.neonViolet,
              onPressed: _busy ? null : _resendVerification,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.authService.signOut();
                      },
                child: const Text('Sign Out'),
              ),
            ),
          ],
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
          ? 'Sign-in expired. Sign in again.'
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
  const _AuthStatusMessage({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.retryEnabled,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool retryEnabled;

  @override
  Widget build(BuildContext context) {
    return _AuthGlassShell(
      backgroundAssetPath: AppAssets.bgTemporalRecovery,
      child: TemporalGlassSurface(
        accent: AppColors.memoryAmber,
        opacity: 0.94,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.memoryAmber,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: retryEnabled ? onRetry : null,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                retryEnabled ? 'Retry sign-in services' : 'Stopping safely',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLoadingShell extends StatelessWidget {
  const _AuthLoadingShell();

  @override
  Widget build(BuildContext context) {
    return const _AuthGlassShell(
      backgroundAssetPath: AppAssets.bgArrival,
      maxWidth: 160,
      child: TemporalGlassSurface(
        padding: EdgeInsets.all(22),
        child: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.neonCyan,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGlassShell extends StatelessWidget {
  const _AuthGlassShell({
    required this.backgroundAssetPath,
    required this.child,
    this.maxWidth = 520,
  });

  final String backgroundAssetPath;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      backgroundAssetPath: backgroundAssetPath,
      overlayOpacity: 0.56,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

InputDecoration _authFieldDecoration({
  required String label,
  required IconData icon,
  required Color accent,
  required Widget trailing,
}) {
  final OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: accent.withValues(alpha: 0.42)),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: accent, letterSpacing: 0),
    prefixIcon: Icon(icon, color: accent),
    suffixIcon: trailing,
    filled: true,
    fillColor: AppColors.bgSecondary.withValues(alpha: 0.86),
    constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: accent, width: 1.4),
    ),
  );
}
