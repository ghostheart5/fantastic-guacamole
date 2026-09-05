part of 'app_bootstrap.dart';

Future<void> runStartupStorageSequence({
  required StartupCancellationToken cancellationToken,
  required Future<void> Function() initializeHive,
  required Future<void> Function() initializeSharedPreferences,
  required Future<void> Function() initializeSensitivePreferences,
  required Future<void> Function() runStorageMigration,
}) async {
  await initializeHive();
  if (cancellationToken.isCancelled) {
    return;
  }
  await initializeSharedPreferences();
  if (cancellationToken.isCancelled) {
    return;
  }
  await initializeSensitivePreferences();
  if (cancellationToken.isCancelled) {
    return;
  }
  await runStorageMigration();
}

StartupBootstrapResult? _productionReadinessBlockResult(
  List<String> readinessIssues,
) {
  final bool productionReadinessBlocked =
      Env.resolveShouldBlockStartupForProductionReadiness(
        enforceProductionReadiness: Env.enforceProductionReadiness,
        isProduction: Env.isProduction,
        readinessIssues: readinessIssues,
      );
  if (!productionReadinessBlocked) {
    return null;
  }

  Logger.errorCode(
    code: AppDiagnosticCode.startupReadinessBlocked,
    debugMessage:
        'Production readiness enforcement blocked startup: '
        '${readinessIssues.length} issue(s).',
  );
  RuntimeDiagnostics.recordState(
    'startup.blocked',
    message: 'production readiness requirements were not met',
    data: <String, Object?>{'issueCount': readinessIssues.length},
  );
  return const StartupBootstrapResult(
    hasOnboarded: false,
    hasSeenWelcome: false,
    startupError: null,
    productionReadinessBlocked: true,
  );
}

Future<StartupBootstrapResult> _initializeStartup(
  WidgetRef ref,
  StartupCancellationToken cancellationToken,
) async {
  const intelligenceService = IntelligenceService();
  final intelligence = intelligenceService.environmentOnly();
  String? startupError;
  final Stopwatch totalBootstrap = Stopwatch()..start();

  List<String> readinessIssues = intelligenceService
      .productionReadinessIssues();
  final StartupBootstrapResult? preflightBlock =
      _productionReadinessBlockResult(readinessIssues);
  if (preflightBlock != null) {
    return preflightBlock;
  }

  tzdata.initializeTimeZones();
  await _configureLocalTimezone(cancellationToken);
  if (cancellationToken.isCancelled) {
    return _cancelledStartupResult;
  }

  final String? storageIssue = await _measureIssueStage(
    'storage',
    () => _initStorageSafe(cancellationToken),
    cancellationToken: cancellationToken,
  );
  if (cancellationToken.isCancelled) {
    return _cancelledStartupResult;
  }
  startupError = _appendStartupIssue(startupError, storageIssue ?? '');

  final String? firebaseIssue = await _measureIssueStage(
    'firebase',
    () => _initFirebaseSafe(
      isMockMode: intelligence.flags.mockMode,
      cancellationToken: cancellationToken,
    ),
    cancellationToken: cancellationToken,
  );
  if (cancellationToken.isCancelled) {
    return _cancelledStartupResult;
  }
  startupError = _appendStartupIssue(startupError, firebaseIssue ?? '');

  final bool firebaseInitialized = Firebase.apps.isNotEmpty;
  final String? firebaseProjectId = firebaseInitialized
      ? Firebase.app().options.projectId
      : null;
  readinessIssues = intelligenceService.productionReadinessIssues(
    firebaseInitialized: firebaseInitialized,
    firebaseProjectId: firebaseProjectId,
  );
  final StartupBootstrapResult? firebaseReadinessBlock =
      _productionReadinessBlockResult(readinessIssues);
  if (firebaseReadinessBlock != null) {
    return firebaseReadinessBlock;
  }

  final String? supabaseIssue = await _measureIssueStage(
    'supabase',
    () => _initSupabaseSafe(
      isMockMode: intelligence.flags.mockMode,
      cancellationToken: cancellationToken,
    ),
    cancellationToken: cancellationToken,
  );
  if (cancellationToken.isCancelled) {
    return _cancelledStartupResult;
  }
  startupError = _appendStartupIssue(startupError, supabaseIssue ?? '');

  final PrefsLoadResult prefsResult = await _measurePrefsStage(
    () => _loadPrefsSafe(cancellationToken),
    cancellationToken: cancellationToken,
  );
  if (cancellationToken.isCancelled) {
    return _cancelledStartupResult;
  }

  unawaited(
    _measureIssueStage(
      'notifications',
      () => _initNotificationSchedulerSafe(
        isMockMode: intelligence.flags.mockMode,
      ),
      cancellationToken: cancellationToken,
    ),
  );
  unawaited(
    _measureIssueStage(
      'deep_links',
      _initDeepLinksSafe,
      cancellationToken: cancellationToken,
    ),
  );
  startupError = _appendStartupIssue(startupError, prefsResult.issue ?? '');

  final bool hasOnboarded = prefsResult.hasOnboarded;
  final bool hasSeenWelcome = prefsResult.hasSeenWelcome;

  if (readinessIssues.isNotEmpty) {
    Logger.warn(
      'Production readiness issues detected: ${readinessIssues.length}',
    );
    RuntimeDiagnostics.record(
      'Production readiness issues: ${readinessIssues.length}',
    );
    startupError = _appendStartupIssue(
      startupError,
      'Production readiness configuration is incomplete:\n- ${readinessIssues.join('\n- ')}',
    );
  }

  Logger.info(
    startupError == null || startupError.trim().isEmpty
        ? 'Startup completed successfully.'
        : 'Startup completed in degraded mode.',
  );
  RuntimeDiagnostics.record(
    startupError == null || startupError.trim().isEmpty
        ? 'Startup completed successfully.'
        : 'Startup completed in degraded mode.',
  );

  totalBootstrap.stop();
  Logger.info(
    'Startup bootstrap total=${totalBootstrap.elapsedMilliseconds}ms',
  );
  RuntimeDiagnostics.recordState(
    'startup.complete',
    message: startupError == null || startupError.trim().isEmpty
        ? 'ok'
        : 'degraded',
    data: <String, Object?>{
      'durationMs': totalBootstrap.elapsedMilliseconds,
      'hasError': startupError != null && startupError.trim().isNotEmpty,
    },
  );

  return StartupBootstrapResult(
    hasOnboarded: hasOnboarded,
    hasSeenWelcome: hasSeenWelcome,
    startupError: startupError,
    productionReadinessBlocked: false,
  );
}

Future<void> _configureLocalTimezone(
  StartupCancellationToken cancellationToken,
) async {
  try {
    final timezoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    if (cancellationToken.isCancelled) {
      return;
    }
    final tz.Location location = tz.getLocation(timezoneName);
    tz.setLocalLocation(location);
    Logger.log('Startup', 'Timezone configured: $timezoneName');
    RuntimeDiagnostics.record('Timezone configured: $timezoneName');
  } catch (error) {
    if (cancellationToken.isCancelled) {
      return;
    }
    Logger.warn('Failed to configure local timezone.');
    RuntimeDiagnostics.record('Failed to configure local timezone.');
  }
}

Future<String?> _initStorageSafe(
  StartupCancellationToken cancellationToken,
) async {
  try {
    Logger.log('Startup', 'Initializing local storage...');
    RuntimeDiagnostics.record('Initializing local storage...');
    await runStartupStorageSequence(
      cancellationToken: cancellationToken,
      initializeHive: HiveService.init,
      initializeSharedPreferences: SharedPrefsService.init,
      initializeSensitivePreferences: SensitivePrefsStore.instance.init,
      runStorageMigration: StorageMigration.run,
    );
    if (cancellationToken.isCancelled) {
      return null;
    }
    Logger.log('Startup', 'Local storage initialized.');
    RuntimeDiagnostics.record('Local storage initialized.');
    return null;
  } on Object catch (error) {
    if (cancellationToken.isCancelled) {
      return null;
    }
    Logger.errorCode(
      code: AppDiagnosticCode.startupStorageFailed,
      debugMessage: 'Local storage initialization failed.',
      exception: error,
    );
    RuntimeDiagnostics.record('Local storage initialization failed: $error');
    return 'Local storage could not be opened. Restart ChronoSpark and retry.';
  }
}

Future<String?> _measureIssueStage(
  String stage,
  Future<String?> Function() action, {
  required StartupCancellationToken cancellationToken,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  final String? issue = await action();
  if (cancellationToken.isCancelled) {
    return issue;
  }
  sw.stop();
  final String outcome = issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record(
    'Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms',
  );
  return issue;
}

Future<PrefsLoadResult> _measurePrefsStage(
  Future<PrefsLoadResult> Function() action, {
  required StartupCancellationToken cancellationToken,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  final PrefsLoadResult result = await action();
  if (cancellationToken.isCancelled) {
    return result;
  }
  sw.stop();
  final String outcome = result.issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record(
    'Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms',
  );
  return result;
}

Future<String?> _initFirebaseSafe({
  required bool isMockMode,
  required StartupCancellationToken cancellationToken,
}) async {
  if (cancellationToken.isCancelled) {
    return null;
  }
  if (isMockMode) {
    Logger.log('Startup', 'Mock mode active: Firebase startup skipped.');
    RuntimeDiagnostics.record('Mock mode active: Firebase startup skipped.');
    return null;
  }

  Logger.log('Startup', 'Initializing Firebase...');
  RuntimeDiagnostics.record('Initializing Firebase...');
  final String? issue = await const FirebaseBootstrap().initialize(
    isMockMode: isMockMode,
    shouldContinue: () => !cancellationToken.isCancelled,
  );
  if (cancellationToken.isCancelled) {
    return issue;
  }
  if (issue == null) {
    Logger.log('Startup', 'Firebase initialized.');
    RuntimeDiagnostics.record('Firebase initialized.');
    unawaited(_captureDiagnosticsContext(cancellationToken));
  } else {
    Logger.errorCode(
      code: AppDiagnosticCode.startupFirebaseFailed,
      debugMessage: 'Firebase initialization failed.',
      exception: issue,
    );
    RuntimeDiagnostics.record('Firebase initialization failed: $issue');
  }
  return issue;
}

Future<void> _captureDiagnosticsContext(
  StartupCancellationToken cancellationToken,
) async {
  try {
    final DiagnosticsContext context =
        await DiagnosticsContextService.collect();
    if (cancellationToken.isCancelled) {
      return;
    }
    RuntimeDiagnostics.recordState(
      'diagnostics.context',
      message: 'Captured app/device diagnostics context',
      data: context.toMap(),
    );
  } on Object catch (_, stackTrace) {
    if (cancellationToken.isCancelled) {
      return;
    }
    Logger.warn('Diagnostics context capture failed (non-fatal).');
    Logger.recordDiagnostic(
      code: AppDiagnosticCode.startupDiagnosticsContextCaptureFailed,
      stackTrace: stackTrace,
    );
  }
}

Future<String?> _initSupabaseSafe({
  required bool isMockMode,
  required StartupCancellationToken cancellationToken,
}) async {
  if (cancellationToken.isCancelled) {
    return null;
  }
  if (isMockMode || !Env.isSupabaseConfigured) {
    Logger.log(
      'Startup',
      'Supabase startup skipped (mockMode=$isMockMode, configured=${Env.isSupabaseConfigured}).',
    );
    RuntimeDiagnostics.record('Supabase startup skipped.');
    return null;
  }

  Logger.log('Startup', 'Initializing Supabase...');
  RuntimeDiagnostics.record('Initializing Supabase...');
  final String? issue = await const SupabaseClientService().initialize(
    isMockMode: isMockMode,
  );
  if (cancellationToken.isCancelled) {
    return issue;
  }
  if (issue == null) {
    Logger.log('Startup', 'Supabase initialized.');
    RuntimeDiagnostics.record('Supabase initialized.');
  } else {
    Logger.errorCode(
      code: AppDiagnosticCode.startupSupabaseFailed,
      debugMessage: 'Supabase initialization failed.',
      exception: issue,
    );
    RuntimeDiagnostics.record('Supabase initialization failed: $issue');
  }
  return issue;
}

Future<String?> _initNotificationSchedulerSafe({
  required bool isMockMode,
}) async {
  if (isMockMode) {
    Logger.log(
      'Startup',
      'Mock mode active: notification scheduler startup skipped.',
    );
    RuntimeDiagnostics.record(
      'Mock mode active: notification scheduler startup skipped.',
    );
    return null;
  }
  try {
    Logger.log('Startup', 'Initializing notification scheduler...');
    RuntimeDiagnostics.record('Initializing notification scheduler...');
    await NotificationScheduler().init().timeout(const Duration(seconds: 8));
    Logger.log('Startup', 'Notification scheduler initialized.');
    RuntimeDiagnostics.record('Notification scheduler initialized.');
    return null;
  } on TimeoutException {
    Logger.warn('Notification scheduler startup timed out (non-fatal).');
    RuntimeDiagnostics.record(
      'Notification scheduler startup timed out (non-fatal).',
    );
    return null;
  } on Object catch (error) {
    Logger.warn('Notification scheduler startup failed (non-fatal): $error');
    RuntimeDiagnostics.record(
      'Notification scheduler startup failed (non-fatal).',
    );
    return null;
  }
}

Future<String?> _initDeepLinksSafe() async {
  try {
    Logger.log('Startup', 'Initializing deep links...');
    RuntimeDiagnostics.record('Initializing deep links...');
    await DeepLinkService.instance.initializeEarly().timeout(
      const Duration(seconds: 6),
    );
    Logger.log('Startup', 'Deep links initialized.');
    RuntimeDiagnostics.record('Deep links initialized.');
    return null;
  } on TimeoutException {
    Logger.warn('Deep link initialization timed out (non-fatal).');
    RuntimeDiagnostics.record(
      'Deep link initialization timed out (non-fatal).',
    );
    return null;
  } on Object catch (error) {
    Logger.warn('Deep link initialization failed (non-fatal): $error');
    RuntimeDiagnostics.record('Deep link initialization failed (non-fatal).');
    return null;
  }
}

/// Account-owned identity must never run against signed-out or unverified
/// storage. The callback is lazy so even the scoped service is read only after
/// the account boundary has granted access.
Future<void> runAccountIdentityStartup({
  required AccountStorageScope scope,
  required Future<String> Function() ensureIdentity,
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (!scope.isWritable) {
    return;
  }
  // This operation uses an immutable account-scoped store. A slow native
  // operation can finish only in that verified namespace; it must not hold
  // the loading screen indefinitely after the global bootstrap has settled.
  await ensureIdentity().timeout(timeout);
}

Future<String?> _initIdentitySafe(
  WidgetRef ref,
  StartupCancellationToken cancellationToken,
) async {
  if (cancellationToken.isCancelled) {
    return null;
  }
  try {
    Logger.log('Startup', 'Bootstrapping identity...');
    RuntimeDiagnostics.record('Bootstrapping identity...');
    await runAccountIdentityStartup(
      scope: ref.read(accountStorageScopeProvider),
      ensureIdentity: () => ref.read(identityServiceProvider).ensureIdentity(),
    );
    if (cancellationToken.isCancelled) {
      return null;
    }
    Logger.log('Startup', 'Identity bootstrap completed.');
    RuntimeDiagnostics.record('Identity bootstrap completed.');
    return null;
  } on TimeoutException {
    if (cancellationToken.isCancelled) {
      return null;
    }
    Logger.errorCode(code: AppDiagnosticCode.startupIdentityTimedOut);
    RuntimeDiagnostics.record('Identity bootstrap timed out.');
    return 'Identity bootstrap timed out.';
  } on Object catch (error) {
    if (cancellationToken.isCancelled) {
      return null;
    }
    Logger.errorCode(
      code: AppDiagnosticCode.startupIdentityFailed,
      debugMessage: 'Identity bootstrap failed.',
      exception: error,
    );
    RuntimeDiagnostics.record('Identity bootstrap failed.');
    return 'Account state could not be restored. Sign in again and retry.';
  }
}

String? _appendStartupIssue(String? current, String next) {
  final String normalizedNext = next.trim();
  if (normalizedNext.isEmpty) {
    return current;
  }

  final String normalizedCurrent = current?.trim() ?? '';
  if (normalizedCurrent.isEmpty) {
    return normalizedNext;
  }

  return '$normalizedCurrent\n$normalizedNext';
}
