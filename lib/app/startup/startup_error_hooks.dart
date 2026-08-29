part of 'app_bootstrap.dart';

class AppBootstrapper {
  const AppBootstrapper();

  void run() {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      await _loadDotEnv();
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
      final String exceptionText = Logger.redactSensitive(
        errorDetails.exceptionAsString(),
      );
      final String stack = Logger.redactSensitive(
        (errorDetails.stack ?? StackTrace.current).toString(),
      );
      if (kDebugMode || Env.enableVerboseLogs) {
        debugPrint('FLUTTER_ERROR_MARKER >>> $exceptionText');
        debugPrint(stack);
        debugPrint('FLUTTER_ERROR_MARKER <<<');
      }
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          prefix: 'Flutter framework error',
          error: exceptionText,
          stack: stack,
        ),
      );
      ErrorBoundary.reportGlobalError(
        errorDetails.exception,
        errorDetails.stack,
      );
      if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          Exception(exceptionText),
          errorDetails.stack,
          reason: 'Flutter framework error',
          fatal: true,
        );
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final String errorText = Logger.redactSensitive(error.toString());
      final String stackText = Logger.redactSensitive(stack.toString());
      if (kDebugMode || Env.enableVerboseLogs) {
        debugPrint('PLATFORM_ERROR_MARKER >>> $errorText');
        debugPrint(stackText);
        debugPrint('PLATFORM_ERROR_MARKER <<<');
      }
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          prefix: 'Platform dispatcher uncaught error',
          error: errorText,
          stack: stackText,
        ),
      );
      ErrorBoundary.reportGlobalError(error, stack);
      if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          Exception(errorText),
          stack,
          reason: 'Platform dispatcher uncaught error',
          fatal: true,
        );
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
      FirebaseCrashlytics.instance.recordError(
        Exception('Uncaught zone error (${error.runtimeType})'),
        null,
        fatal: true,
      );
    }
  }

  Future<void> _loadDotEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      Logger.info('Loaded local .env configuration.');
    } on Object {
      Logger.info('No local .env loaded.');
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
  if (kDebugMode || Env.enableVerboseLogs) {
    return '$prefix (${error.runtimeType})\n${appLine.isEmpty ? '' : 'app: $appLine\n'}$stack';
  }
  return '$prefix (${error.runtimeType})';
}

bool get _supportsCrashlytics =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
