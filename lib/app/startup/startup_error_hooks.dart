part of 'app_bootstrap.dart';

class AppBootstrapper {
  const AppBootstrapper();

  void run() {
    runZonedGuarded(() {
      WidgetsFlutterBinding.ensureInitialized();
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
      final StackTrace stackTrace = errorDetails.stack ?? StackTrace.current;
      final String stack = Logger.redactSensitive(stackTrace.toString());
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          releaseCode: 'startup.flutter_framework_error',
          prefix: 'Flutter framework error',
          error: exceptionText,
          stack: stack,
        ),
      );
      ErrorBoundary.reportGlobalError(
        errorDetails.exception,
        errorDetails.stack,
      );
      Logger.errorCode(
        code: AppDiagnosticCode.startupFlutterFrameworkError,
        debugMessage: 'Flutter framework error.',
        exception: errorDetails.exception,
        stackTrace: stackTrace,
        fatal: true,
        debugMarker: 'FLUTTER_ERROR_MARKER',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final String errorText = Logger.redactSensitive(error.toString());
      final String stackText = Logger.redactSensitive(stack.toString());
      RuntimeDiagnostics.record(
        _formatGlobalErrorForDiagnostics(
          releaseCode: 'startup.platform_dispatcher_error',
          prefix: 'Platform dispatcher uncaught error',
          error: errorText,
          stack: stackText,
        ),
      );
      ErrorBoundary.reportGlobalError(error, stack);
      Logger.errorCode(
        code: AppDiagnosticCode.startupPlatformDispatcherError,
        debugMessage: 'Platform dispatcher uncaught error.',
        exception: error,
        stackTrace: stack,
        fatal: true,
        debugMarker: 'PLATFORM_ERROR_MARKER',
      );
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
    if (Logger.freeFormOutputEnabled) {
      FlutterError.presentError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
    RuntimeDiagnostics.record(
      _formatGlobalErrorForDiagnostics(
        releaseCode: 'startup.uncaught_zone_error',
        prefix: 'Uncaught zone error',
        error: error,
        stack: stack.toString(),
      ),
    );
    ErrorBoundary.reportGlobalError(error, stack);
    Logger.errorCode(
      code: AppDiagnosticCode.startupUncaughtZoneError,
      debugMessage: 'Uncaught zone error.',
      exception: error,
      stackTrace: stack,
      fatal: true,
    );
  }
}

String _formatGlobalErrorForDiagnostics({
  required String releaseCode,
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
  if (Logger.freeFormOutputEnabled) {
    return '$prefix (${error.runtimeType})\n${appLine.isEmpty ? '' : 'app: $appLine\n'}$stack';
  }
  return 'Diagnostic: $releaseCode';
}
