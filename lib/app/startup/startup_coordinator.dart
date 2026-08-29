part of 'app_bootstrap.dart';

Future<T> runStartupWithTimeout<T>({
  required Future<T> Function(StartupCancellationToken token) initialize,
  required Duration timeout,
  required T Function() onTimeout,
  StartupCancellationToken? cancellationToken,
}) {
  final StartupCancellationToken token =
      cancellationToken ?? StartupCancellationToken();
  final Future<T> source = () async {
    try {
      return await initialize(token);
    } finally {
      token._markSourceSettled();
    }
  }();
  return source.timeout(
    timeout,
    onTimeout: () {
      token.cancel();
      return onTimeout();
    },
  );
}

bool shouldInitializeAccountBoundary({
  required bool productionReadinessBlocked,
  required bool startupTimedOut,
  required bool startupSourceSettled,
}) {
  return !productionReadinessBlocked &&
      (!startupTimedOut || startupSourceSettled);
}

class StartupBootstrapGate extends ConsumerStatefulWidget {
  const StartupBootstrapGate({
    super.key,
    this.initializeStartup = _initializeStartup,
    this.startupTimeout = const Duration(seconds: 45),
  });

  final Future<StartupBootstrapResult> Function(
    WidgetRef ref,
    StartupCancellationToken cancellationToken,
  )
  initializeStartup;
  final Duration startupTimeout;

  @override
  ConsumerState<StartupBootstrapGate> createState() =>
      _StartupBootstrapGateState();
}

class _StartupBootstrapGateState extends ConsumerState<StartupBootstrapGate> {
  bool _ready = false;
  bool _waitingForStartupQuiescence = false;
  bool _productionReadinessBlocked = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    // Last-resort guard. Every stage below catches its own failures, but if
    // anything at all escapes (an Error subtype, a bug in a stage helper) the
    // app must still leave the loading screen. Without this, an escaping
    // throwable means `_ready` is never set and the user sits on a spinner
    // forever with no crash report — strictly worse than crashing.
    StartupBootstrapResult result = const StartupBootstrapResult(
      hasOnboarded: false,
      hasSeenWelcome: false,
      startupError: null,
      productionReadinessBlocked: false,
    );
    String fatalIssue = '';
    bool startupTimedOut = false;
    final StartupCancellationToken cancellationToken =
        StartupCancellationToken();
    try {
      result = await runStartupWithTimeout<StartupBootstrapResult>(
        initialize: (StartupCancellationToken token) =>
            widget.initializeStartup(ref, token),
        timeout: widget.startupTimeout,
        cancellationToken: cancellationToken,
        onTimeout: () {
          startupTimedOut = true;
          Logger.error('Startup bootstrap timed out before completion.');
          RuntimeDiagnostics.record(
            'Startup bootstrap timed out before completion.',
          );
          return const StartupBootstrapResult(
            hasOnboarded: false,
            hasSeenWelcome: false,
            startupError:
                'Startup bootstrap timed out. App started in degraded mode.',
            productionReadinessBlocked: false,
          );
        },
      );
    } on Object catch (error, stackTrace) {
      Logger.errorCategory('Startup', 'Bootstrap failed', error, stackTrace);
      RuntimeDiagnostics.record('Startup bootstrap failed: $error');
      fatalIssue = 'Startup did not complete. App started in degraded mode.';
    }

    if (startupTimedOut) {
      if (!mounted) {
        return;
      }
      setState(() {
        _waitingForStartupQuiescence = true;
      });
      await cancellationToken.whenSourceSettled;
      if (!mounted) {
        return;
      }
    }

    String? stateBootstrapIssue;
    final bool initializeAccountBoundary = shouldInitializeAccountBoundary(
      productionReadinessBlocked: result.productionReadinessBlocked,
      startupTimedOut: startupTimedOut,
      startupSourceSettled: cancellationToken.isSourceSettled,
    );
    if (initializeAccountBoundary) {
      try {
        await ref
            .read(authSessionBoundaryCoordinatorProvider)
            .initialize()
            .timeout(const Duration(seconds: 8));
        final boundary = ref.read(authSessionBoundaryProvider);
        if (boundary.isStorageReady) {
          stateBootstrapIssue = await _runStateBootstrapSafe(ref);
        } else if (boundary.blockingIssue != null) {
          stateBootstrapIssue = boundary.blockingIssue;
        }
      } on TimeoutException {
        stateBootstrapIssue =
            'Account storage verification timed out. Account data remains locked.';
      } on Object catch (error, stackTrace) {
        Logger.errorCategory(
          'Startup',
          'State bootstrap failed',
          error,
          stackTrace,
        );
        stateBootstrapIssue = 'State bootstrap failed.';
      }
    }

    final String? startupError = _appendStartupIssue(
      _appendStartupIssue(result.startupError, fatalIssue),
      stateBootstrapIssue ?? '',
    );
    if (!mounted) {
      return;
    }
    if (!result.productionReadinessBlocked) {
      ref.read(onboardingCompleteProvider.notifier).set(result.hasOnboarded);
      ref
          .read(onboardingWelcomeCompleteProvider.notifier)
          .set(result.hasSeenWelcome);

      if (initializeAccountBoundary) {
        // Prime async route guards outside AppRoot's build phase. Their first
        // stream emissions can otherwise invalidate ProviderScope mid-build.
        ref.read(appRouterProvider);
        // OfflineBanner is part of the first routed frame. Mount its
        // account-scoped queue here, after the auth boundary has settled, so
        // Riverpod does not flush a new account listener during widget build.
        try {
          await ref
              .read(offlineQueueCountProvider.future)
              .timeout(const Duration(seconds: 2));
        } on Object catch (error) {
          Logger.warn('Offline queue prewarm did not complete: $error');
        }
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return;
        }
      }
    }
    setState(() {
      _startupError = startupError;
      _productionReadinessBlocked = result.productionReadinessBlocked;
      _waitingForStartupQuiescence = false;
      _ready = true;
    });
    if (!result.productionReadinessBlocked) {
      AppAnalytics.track('app_open');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF050D1A),
          body: Center(
            child: _waitingForStartupQuiescence
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.lock_outline, color: Color(0xFF00D9F5)),
                        SizedBox(height: 16),
                        Text(
                          'Securing local state',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ChronoSpark will continue when startup services have stopped safely.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8C7D9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AppRoot(
      startupError: _startupError,
      productionReadinessBlocked: _productionReadinessBlocked,
    );
  }
}

Future<String?> _runStateBootstrapSafe(WidgetRef ref) async {
  try {
    await ref
        .read(stateBootstrapProvider.future)
        .timeout(const Duration(seconds: 4));
    Logger.log('Startup', 'State bootstrap completed.');
    RuntimeDiagnostics.record('State bootstrap completed.');
    return null;
  } on TimeoutException {
    Logger.warn('State bootstrap timed out.');
    RuntimeDiagnostics.record('State bootstrap timed out.');
    return 'State bootstrap timed out.';
  } on Object catch (error) {
    Logger.error('State bootstrap failed.', error);
    RuntimeDiagnostics.record('State bootstrap failed.');
    return 'State bootstrap failed. Local data remains available; retry from the app when ready.';
  }
}
