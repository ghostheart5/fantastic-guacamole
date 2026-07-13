import 'dart:async';

import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/diagnostics_context_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/core/observers/riverpod_observer.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_migration.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
    show
        onboardingCompleteProvider,
        onboardingCompleteStorageKey,
        onboardingContentVersionStorageKey;
import 'package:fantastic_guacamole/state/core/state_bootstrap.dart'
    show stateBootstrapProvider;
import 'package:fantastic_guacamole/state/providers/service_providers.dart'
    show identityServiceProvider;
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_bootstrap.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/system_boot.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class AppBootstrapper {
  const AppBootstrapper();

  void run() {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      await _loadDotEnv();
      FirebaseMessagingBootstrap.configureBackgroundHandler();
      _runApp();
    }, _handleUncaughtZoneError);
  }

  void _runApp() {
    final config = AppConfig.fromEnv();
    final intelligence = const IntelligenceService().environmentOnly();
    Logger.enabled = config.verboseLogs;
    Logger.info(
      'Startup begin. Flavor=${config.flavor.value}, '
      'mockMode=${intelligence.flags.mockMode}, '
      'paywallDisabled=${intelligence.flags.paywallDisabled}, '
      'mockLogin=${intelligence.flags.mockLoginEnabled}.',
    );
    RuntimeDiagnostics.recordState(
      'startup.begin',
      message: 'startup initialized',
      data: intelligence.toMap(),
    );

    FlutterError.onError = (errorDetails) {
      FlutterError.presentError(errorDetails);
      final String stack = (errorDetails.stack ?? StackTrace.current)
          .toString();
      debugPrint(
        'FLUTTER_ERROR_MARKER >>> ${errorDetails.exceptionAsString()}',
      );
      debugPrint(stack);
      debugPrint('FLUTTER_ERROR_MARKER <<<');
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          prefix: 'Flutter framework error',
          error: errorDetails.exceptionAsString(),
          stack: stack,
        ),
      );
      ErrorBoundary.reportGlobalError(
        errorDetails.exception,
        errorDetails.stack,
      );
      if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('PLATFORM_ERROR_MARKER >>> $error');
      debugPrint(stack.toString());
      debugPrint('PLATFORM_ERROR_MARKER <<<');
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          prefix: 'Platform dispatcher uncaught error',
          error: error,
          stack: stack.toString(),
        ),
      );
      ErrorBoundary.reportGlobalError(error, stack);
      if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };

    runApp(
      ProviderScope(
        observers: [AppObserver()],
        child: const StartupBootstrapGate(),
      ),
    );
  }

  void _handleUncaughtZoneError(Object error, StackTrace stack) {
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    RuntimeDiagnostics.record(
      _formatGlobalErrorForDiagnostics(
        prefix: 'Uncaught zone error',
        error: error,
        stack: stack.toString(),
      ),
    );
    ErrorBoundary.reportGlobalError(error, stack);
    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  }

  Future<void> _loadDotEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      Logger.info('Loaded local .env configuration.');
    } on Object catch (error) {
      Logger.info('No local .env loaded: $error');
    }
  }
}

String _formatGlobalErrorForDiagnostics({
  required String prefix,
  required Object error,
  required String stack,
}) {
  final String appLine = stack
      .split('\n')
      .firstWhere(
        (line) => line.contains('package:fantastic_guacamole/'),
        orElse: () => '',
      )
      .trim();
  return '$prefix: $error\n${appLine.isEmpty ? '' : 'app: $appLine\n'}$stack';
}

bool get _supportsCrashlytics =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

class StartupBootstrapGate extends ConsumerStatefulWidget {
  const StartupBootstrapGate({super.key});

  @override
  ConsumerState<StartupBootstrapGate> createState() =>
      _StartupBootstrapGateState();
}

class _StartupBootstrapGateState extends ConsumerState<StartupBootstrapGate> {
  bool _ready = false;
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
    final StartupBootstrapResult result = await _initializeStartup(ref).timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        Logger.error('Startup bootstrap timed out before completion.');
        RuntimeDiagnostics.record(
          'Startup bootstrap timed out before completion.',
        );
        return const StartupBootstrapResult(
          hasOnboarded: false,
          startupError:
              'Startup bootstrap timed out. App started in degraded mode.',
        );
      },
    );
    final String? stateBootstrapIssue = await _runStateBootstrapSafe(ref);
    final String? startupError = _appendStartupIssue(
      result.startupError,
      stateBootstrapIssue ?? '',
    );
    if (!mounted) {
      return;
    }
    ref.read(onboardingCompleteProvider.notifier).set(result.hasOnboarded);
    setState(() {
      _startupError = startupError;
      _ready = true;
    });
    AppAnalytics.track('app_open');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF050D1A),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppRoot(startupError: _startupError);
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
  } on Exception catch (error) {
    Logger.error('State bootstrap failed.', error);
    RuntimeDiagnostics.record('State bootstrap failed: $error');
    return 'State bootstrap failed: $error';
  }
}

class StartupBootstrapResult {
  const StartupBootstrapResult({
    required this.hasOnboarded,
    required this.startupError,
  });

  final bool hasOnboarded;
  final String? startupError;
}

class PrefsLoadResult {
  const PrefsLoadResult({required this.hasOnboarded, required this.issue});

  final bool hasOnboarded;
  final String? issue;
}

Future<StartupBootstrapResult> _initializeStartup(WidgetRef ref) async {
  const intelligenceService = IntelligenceService();
  final intelligence = intelligenceService.environmentOnly();
  String? startupError;
  final Stopwatch totalBootstrap = Stopwatch()..start();

  const SystemBoot();
  tzdata.initializeTimeZones();
  await _configureLocalTimezone();

  final String? storageIssue = await _measureIssueStage(
    'storage',
    _initStorageSafe,
  );
  startupError = _appendStartupIssue(startupError, storageIssue ?? '');

  final String? firebaseIssue = await _measureIssueStage(
    'firebase',
    () => _initFirebaseSafe(isMockMode: intelligence.flags.mockMode),
  );
  startupError = _appendStartupIssue(startupError, firebaseIssue ?? '');

  final String? messagingIssue = await _measureIssueStage(
    'push_notifications',
    () => _initMessagingSafe(isMockMode: intelligence.flags.mockMode),
  );
  startupError = _appendStartupIssue(startupError, messagingIssue ?? '');

  final String? supabaseIssue = await _measureIssueStage(
    'supabase',
    () => _initSupabaseSafe(isMockMode: intelligence.flags.mockMode),
  );
  startupError = _appendStartupIssue(startupError, supabaseIssue ?? '');

  final String? identityIssue = await _measureIssueStage(
    'identity',
    () => _initIdentitySafe(ref),
  );
  startupError = _appendStartupIssue(startupError, identityIssue ?? '');

  final PrefsLoadResult prefsResult = await _measurePrefsStage(_loadPrefsSafe);

  unawaited(
    _measureIssueStage(
      'notifications',
      () => _initNotificationSchedulerSafe(
        isMockMode: intelligence.flags.mockMode,
      ),
    ),
  );
  unawaited(_measureIssueStage('deep_links', _initDeepLinksSafe));
  startupError = _appendStartupIssue(startupError, prefsResult.issue ?? '');

  final bool hasOnboarded = prefsResult.hasOnboarded;

  final List<String> readinessIssues = intelligenceService
      .productionReadinessIssues();
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
    startupError: startupError,
  );
}

Future<void> _configureLocalTimezone() async {
  try {
    final String timezoneName = await FlutterTimezone.getLocalTimezone();
    final tz.Location location = tz.getLocation(timezoneName);
    tz.setLocalLocation(location);
    Logger.log('Startup', 'Timezone configured: $timezoneName');
    RuntimeDiagnostics.record('Timezone configured: $timezoneName');
  } catch (error) {
    Logger.warn('Failed to configure local timezone: $error');
    RuntimeDiagnostics.record('Failed to configure local timezone: $error');
  }
}

Future<String?> _initStorageSafe() async {
  try {
    Logger.log('Startup', 'Initializing local storage...');
    RuntimeDiagnostics.record('Initializing local storage...');
    await HiveService.init();
    await SharedPrefsService.init();
    await SensitivePrefsStore.instance.init();
    await StorageMigration.run();
    Logger.log('Startup', 'Local storage initialized.');
    RuntimeDiagnostics.record('Local storage initialized.');
    return null;
  } on Exception catch (error) {
    Logger.error('Local storage initialization failed.', error);
    RuntimeDiagnostics.record('Local storage initialization failed: $error');
    return 'Local storage initialization failed: $error';
  }
}

Future<String?> _measureIssueStage(
  String stage,
  Future<String?> Function() action,
) async {
  final Stopwatch sw = Stopwatch()..start();
  final String? issue = await action();
  sw.stop();
  final String outcome = issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record(
    'Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms',
  );
  return issue;
}

Future<PrefsLoadResult> _measurePrefsStage(
  Future<PrefsLoadResult> Function() action,
) async {
  final Stopwatch sw = Stopwatch()..start();
  final PrefsLoadResult result = await action();
  sw.stop();
  final String outcome = result.issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record(
    'Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms',
  );
  return result;
}

Future<String?> _initFirebaseSafe({required bool isMockMode}) async {
  if (isMockMode) {
    Logger.log('Startup', 'Mock mode active: Firebase startup skipped.');
    RuntimeDiagnostics.record('Mock mode active: Firebase startup skipped.');
    return null;
  }

  Logger.log('Startup', 'Initializing Firebase...');
  RuntimeDiagnostics.record('Initializing Firebase...');
  final String? issue = await const FirebaseBootstrap().initialize(
    isMockMode: isMockMode,
  );
  if (issue == null) {
    Logger.log('Startup', 'Firebase initialized.');
    RuntimeDiagnostics.record('Firebase initialized.');
    unawaited(_captureDiagnosticsContext());
  } else {
    Logger.error('Firebase initialization failed.', issue);
    RuntimeDiagnostics.record('Firebase initialization failed: $issue');
  }
  return issue;
}

Future<String?> _initMessagingSafe({required bool isMockMode}) async {
  if (isMockMode) {
    Logger.log(
      'Startup',
      'Mock mode active: Push notifications startup skipped.',
    );
    RuntimeDiagnostics.record(
      'Mock mode active: Push notifications startup skipped.',
    );
    return null;
  }

  Logger.log('Startup', 'Initializing Firebase Messaging...');
  RuntimeDiagnostics.record('Initializing Firebase Messaging...');
  final String? issue = await const FirebaseMessagingBootstrap().initialize(
    isMockMode: isMockMode,
  );
  if (issue == null) {
    Logger.log('Startup', 'Firebase Messaging initialized.');
    RuntimeDiagnostics.record('Firebase Messaging initialized.');
  } else {
    Logger.warn(issue);
    RuntimeDiagnostics.record(issue);
  }
  return issue;
}

Future<void> _captureDiagnosticsContext() async {
  try {
    final DiagnosticsContext context =
        await DiagnosticsContextService.collect();
    RuntimeDiagnostics.recordState(
      'diagnostics.context',
      message: 'Captured app/device diagnostics context',
      data: context.toMap(),
    );

    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_version',
        context.version,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'build_number',
        context.buildNumber,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'platform',
        context.platform,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'os_version',
        context.osVersion,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'device_model',
        context.model,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'is_physical_device',
        context.isPhysicalDevice,
      );
    }
  } on Object catch (error, stackTrace) {
    Logger.warn('Diagnostics context capture failed (non-fatal): $error');
    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Failed to capture diagnostics context',
        fatal: false,
      );
    }
  }
}

Future<String?> _initSupabaseSafe({required bool isMockMode}) async {
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
  if (issue == null) {
    Logger.log('Startup', 'Supabase initialized.');
    RuntimeDiagnostics.record('Supabase initialized.');
  } else {
    Logger.error('Supabase initialization failed.', issue);
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
  } on Exception catch (error) {
    Logger.warn('Notification scheduler startup failed (non-fatal): $error');
    RuntimeDiagnostics.record(
      'Notification scheduler startup failed (non-fatal): $error',
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
  } on Exception catch (error) {
    Logger.warn('Deep link initialization failed (non-fatal): $error');
    RuntimeDiagnostics.record(
      'Deep link initialization failed (non-fatal): $error',
    );
    return null;
  }
}

Future<String?> _initIdentitySafe(WidgetRef ref) async {
  try {
    Logger.log('Startup', 'Bootstrapping identity...');
    RuntimeDiagnostics.record('Bootstrapping identity...');
    await ref
        .read(identityServiceProvider)
        .ensureIdentity()
        .timeout(const Duration(seconds: 8));
    Logger.log('Startup', 'Identity bootstrap completed.');
    RuntimeDiagnostics.record('Identity bootstrap completed.');
    return null;
  } on TimeoutException {
    Logger.warn('Identity bootstrap timed out.');
    RuntimeDiagnostics.record('Identity bootstrap timed out.');
    return 'Identity bootstrap timed out.';
  } on Exception catch (error) {
    Logger.error('Identity bootstrap failed.', error);
    RuntimeDiagnostics.record('Identity bootstrap failed: $error');
    return 'Identity bootstrap failed: $error';
  }
}

Future<PrefsLoadResult> _loadPrefsSafe() async {
  bool hasOnboarded = false;

  try {
    Logger.log('Startup', 'Loading local preferences...');
    RuntimeDiagnostics.record('Loading local preferences...');
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 6),
    );
    final Object? rawOnboardingComplete = prefs.get(
      onboardingCompleteStorageKey,
    );
    hasOnboarded = _coercePrefsBool(rawOnboardingComplete) ?? false;
    if (rawOnboardingComplete is String) {
      await prefs.setBool(onboardingCompleteStorageKey, hasOnboarded);
    }

    final Object? rawOnboardingVersion = prefs.get(
      onboardingContentVersionStorageKey,
    );
    final int storedOnboardingVersion =
        _coercePrefsInt(rawOnboardingVersion) ?? 0;
    if (rawOnboardingVersion is String) {
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        storedOnboardingVersion,
      );
    }
    final int currentOnboardingVersion = TutorialContent.contentVersion;

    if (storedOnboardingVersion < currentOnboardingVersion) {
      hasOnboarded = false;
      await prefs.setBool(onboardingCompleteStorageKey, false);
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        currentOnboardingVersion,
      );
      Logger.log(
        'Startup',
        'Onboarding content version updated '
            '($storedOnboardingVersion -> $currentOnboardingVersion); replay required.',
      );
      RuntimeDiagnostics.record(
        'Onboarding content version updated '
        '($storedOnboardingVersion -> $currentOnboardingVersion); replay required.',
      );
    }

    Logger.log(
      'Startup',
      'Local preferences loaded. onboardingComplete=$hasOnboarded',
    );
    RuntimeDiagnostics.record(
      'Local preferences loaded. onboardingComplete=$hasOnboarded',
    );
    return PrefsLoadResult(hasOnboarded: hasOnboarded, issue: null);
  } on TimeoutException {
    Logger.warn('Local preferences initialization timed out.');
    RuntimeDiagnostics.record('Local preferences initialization timed out.');
    return const PrefsLoadResult(
      hasOnboarded: false,
      issue: 'Local preferences initialization timed out.',
    );
  } on Object catch (error) {
    Logger.error('Local preferences initialization failed.', error);
    RuntimeDiagnostics.record(
      'Local preferences initialization failed: $error',
    );
    return PrefsLoadResult(
      hasOnboarded: false,
      issue: 'Local preferences initialization failed: $error',
    );
  }
}

bool? _coercePrefsBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  return null;
}

int? _coercePrefsInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
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
