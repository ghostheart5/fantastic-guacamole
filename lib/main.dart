import 'dart:async';

import 'package:fantastic_guacamole/app/app.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/firebase_options.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/core/observers/riverpod_observer.dart';
import 'package:fantastic_guacamole/core/storage/hive_service.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/storage/storage_migration.dart';
import 'package:fantastic_guacamole/features/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/state/intelligence/intelligence_service.dart';
import 'package:fantastic_guacamole/system/system_boot.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnv();
  final intelligence = const IntelligenceService().environmentOnly();
  Logger.enabled = config.verboseLogs;
  Logger.info(
    'Startup begin. Flavor=${intelligence.environment.appFlavor}, '
    'mockMode=${intelligence.flags.mockMode}, '
    'paywallDisabled=${intelligence.flags.paywallDisabled}, '
    'mockLogin=${intelligence.flags.mockLoginEnabled}.',
  );
  RuntimeDiagnostics.recordState(
    'startup.begin',
    message: 'startup initialized',
    data: intelligence.toMap(),
  );

  runApp(ProviderScope(observers: [AppObserver()], child: const _StartupBootstrapGate()));
}

class _StartupBootstrapGate extends ConsumerStatefulWidget {
  const _StartupBootstrapGate();

  @override
  ConsumerState<_StartupBootstrapGate> createState() => _StartupBootstrapGateState();
}

class _StartupBootstrapGateState extends ConsumerState<_StartupBootstrapGate> {
  bool _ready = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final _StartupBootstrapResult result = await _initializeStartup(ref).timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        Logger.error('Startup bootstrap timed out before completion.');
        RuntimeDiagnostics.record('Startup bootstrap timed out before completion.');
        return const _StartupBootstrapResult(
          hasOnboarded: false,
          startupError: 'Startup bootstrap timed out. App started in degraded mode.',
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
    await ref.read(stateBootstrapProvider.future).timeout(const Duration(seconds: 4));
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

class _StartupBootstrapResult {
  const _StartupBootstrapResult({required this.hasOnboarded, required this.startupError});

  final bool hasOnboarded;
  final String? startupError;
}

class _PrefsLoadResult {
  const _PrefsLoadResult({required this.hasOnboarded, required this.issue});

  final bool hasOnboarded;
  final String? issue;
}

Future<_StartupBootstrapResult> _initializeStartup(WidgetRef ref) async {
  const intelligenceService = IntelligenceService();
  final intelligence = intelligenceService.environmentOnly();
  String? startupError;
  final Stopwatch totalBootstrap = Stopwatch()..start();

  const SystemBoot();
  tz.initializeTimeZones();

  final Future<String?> storageIssueFuture = _measureIssueStage('storage', _initStorageSafe);
  final Future<String?> firebaseIssueFuture = _measureIssueStage(
    'firebase',
    () => _initFirebaseSafe(isMockMode: intelligence.flags.mockMode),
  );
  final Future<String?> notificationIssueFuture = _measureIssueStage(
    'notifications',
    () => _initNotificationSchedulerSafe(isMockMode: intelligence.flags.mockMode),
  );
  final Future<String?> identityIssueFuture = _measureIssueStage(
    'identity',
    () => _initIdentitySafe(ref),
  );
  final Future<_PrefsLoadResult> prefsResultFuture = _measurePrefsStage(_loadPrefsSafe);

  final List<String?> startupIssues = await Future.wait<String?>(<Future<String?>>[
    storageIssueFuture,
    firebaseIssueFuture,
    notificationIssueFuture,
    identityIssueFuture,
  ]);
  final _PrefsLoadResult prefsResult = await prefsResultFuture;

  for (final String? issue in startupIssues) {
    startupError = _appendStartupIssue(startupError, issue ?? '');
  }
  startupError = _appendStartupIssue(startupError, prefsResult.issue ?? '');

  final bool hasOnboarded = prefsResult.hasOnboarded;

  final List<String> readinessIssues = intelligenceService.productionReadinessIssues();
  if (readinessIssues.isNotEmpty) {
    Logger.warn('Production readiness issues detected: ${readinessIssues.length}');
    RuntimeDiagnostics.record('Production readiness issues: ${readinessIssues.length}');
    startupError = _appendStartupIssue(
      startupError,
      'Production readiness configuration is incomplete:\n- '
      '${readinessIssues.join('\n- ')}',
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
  Logger.info('Startup bootstrap total=${totalBootstrap.elapsedMilliseconds}ms');
  RuntimeDiagnostics.recordState(
    'startup.complete',
    message: startupError == null || startupError.trim().isEmpty ? 'ok' : 'degraded',
    data: <String, Object?>{
      'durationMs': totalBootstrap.elapsedMilliseconds,
      'hasError': startupError != null && startupError.trim().isNotEmpty,
    },
  );

  return _StartupBootstrapResult(hasOnboarded: hasOnboarded, startupError: startupError);
}

Future<String?> _initStorageSafe() async {
  try {
    Logger.log('Startup', 'Initializing local storage...');
    RuntimeDiagnostics.record('Initializing local storage...');
    await HiveService.init();
    await SharedPrefsService.init();
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

Future<String?> _measureIssueStage(String stage, Future<String?> Function() action) async {
  final Stopwatch sw = Stopwatch()..start();
  final String? issue = await action();
  sw.stop();
  final String outcome = issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record('Startup stage $stage: $outcome in ${sw.elapsedMilliseconds}ms');
  return issue;
}

Future<_PrefsLoadResult> _measurePrefsStage(Future<_PrefsLoadResult> Function() action) async {
  final Stopwatch sw = Stopwatch()..start();
  final _PrefsLoadResult result = await action();
  sw.stop();
  final String outcome = result.issue == null ? 'ok' : 'issue';
  Logger.info('Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms');
  RuntimeDiagnostics.record('Startup stage prefs: $outcome in ${sw.elapsedMilliseconds}ms');
  return result;
}

Future<String?> _initFirebaseSafe({required bool isMockMode}) async {
  if (isMockMode) {
    Logger.log('Startup', 'Mock mode active: Firebase startup skipped.');
    RuntimeDiagnostics.record('Mock mode active: Firebase startup skipped.');
    return null;
  }
  try {
    if (Firebase.apps.isEmpty) {
      Logger.log('Startup', 'Initializing Firebase...');
      RuntimeDiagnostics.record('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));
      Logger.log('Startup', 'Firebase initialized.');
      RuntimeDiagnostics.record('Firebase initialized.');
    }
    return null;
  } on FirebaseException catch (error) {
    // Hot restarts and some plugin startup paths can race into duplicate init.
    if (error.code == 'duplicate-app') {
      return null;
    }
    Logger.error('Firebase initialization failed.', error);
    RuntimeDiagnostics.record('Firebase initialization failed: $error');
    return 'Firebase initialization failed: $error';
  } on TimeoutException {
    Logger.warn('Firebase initialization timed out.');
    RuntimeDiagnostics.record('Firebase initialization timed out.');
    return 'Firebase initialization timed out. The app started in degraded mode.';
  } on Exception catch (error) {
    Logger.error('Firebase initialization failed.', error);
    RuntimeDiagnostics.record('Firebase initialization failed: $error');
    return 'Firebase initialization failed: $error';
  }
}

Future<String?> _initNotificationSchedulerSafe({required bool isMockMode}) async {
  if (isMockMode) {
    Logger.log('Startup', 'Mock mode active: notification scheduler startup skipped.');
    RuntimeDiagnostics.record('Mock mode active: notification scheduler startup skipped.');
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
    Logger.warn('Notification scheduler startup timed out.');
    RuntimeDiagnostics.record('Notification scheduler startup timed out.');
    return 'Notification scheduler startup timed out.';
  } on Exception catch (error) {
    Logger.error('Notification scheduler startup failed.', error);
    RuntimeDiagnostics.record('Notification scheduler startup failed: $error');
    return 'Notification scheduler failed to initialize: $error';
  }
}

Future<String?> _initIdentitySafe(WidgetRef ref) async {
  try {
    Logger.log('Startup', 'Bootstrapping identity...');
    RuntimeDiagnostics.record('Bootstrapping identity...');
    await ref.read(identityServiceProvider).ensureIdentity().timeout(const Duration(seconds: 8));
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

Future<_PrefsLoadResult> _loadPrefsSafe() async {
  bool hasOnboarded = false;

  try {
    Logger.log('Startup', 'Loading local preferences...');
    RuntimeDiagnostics.record('Loading local preferences...');
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 6));
    hasOnboarded = prefs.getBool(onboardingCompleteStorageKey) ?? false;
    Logger.log('Startup', 'Local preferences loaded. onboardingComplete=$hasOnboarded');
    RuntimeDiagnostics.record('Local preferences loaded. onboardingComplete=$hasOnboarded');
    return _PrefsLoadResult(hasOnboarded: hasOnboarded, issue: null);
  } on TimeoutException {
    Logger.warn('Local preferences initialization timed out.');
    RuntimeDiagnostics.record('Local preferences initialization timed out.');
    return const _PrefsLoadResult(
      hasOnboarded: false,
      issue: 'Local preferences initialization timed out.',
    );
  } on Exception catch (error) {
    Logger.error('Local preferences initialization failed.', error);
    RuntimeDiagnostics.record('Local preferences initialization failed: $error');
    return _PrefsLoadResult(
      hasOnboarded: false,
      issue: 'Local preferences initialization failed: $error',
    );
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
