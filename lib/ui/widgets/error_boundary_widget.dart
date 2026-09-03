import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({required this.child, super.key});

  final Widget child;

  static String? _lastReportedErrorFingerprint;
  static bool _isReportingError = false;

  static ErrorBoundaryState? of(BuildContext context) {
    return context.findAncestorStateOfType<ErrorBoundaryState>();
  }

  static void reportGlobalError(Object error, [StackTrace? stackTrace]) {
    final String errorText = Logger.redactSensitive(error.toString());
    final StackTrace effectiveStack = stackTrace ?? StackTrace.current;

    // Prevent recursive ErrorBoundary / Crashlytics / FlutterError loops.
    if (_isReportingError) {
      return;
    }

    // Prevent the exact same error from spamming forever.
    if (_lastReportedErrorFingerprint == errorText) {
      return;
    }

    _isReportingError = true;
    _lastReportedErrorFingerprint = errorText;

    try {
      // Do NOT update notifiers or UI during build.
      // Logger is delayed so it cannot trigger another Flutter build error.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          Logger.errorCode(
            code: 'error_boundary.global_error',
            debugMessage: 'Global error captured.',
            exception: error,
            stackTrace: effectiveStack,
          );
        } catch (_) {
          // Never allow logging to create another crash loop.
        }
      });
    } catch (_) {
      // Never allow error reporting to crash the app.
    } finally {
      _isReportingError = false;
    }
  }

  static void clearGlobalError() {
    _lastReportedErrorFingerprint = null;
  }

  @override
  State<ErrorBoundary> createState() => ErrorBoundaryState();
}

class ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  bool _settingError = false;

  void captureError(Object error, [StackTrace? stackTrace]) {
    ErrorBoundary.reportGlobalError(error, stackTrace);

    if (!mounted || _settingError) {
      return;
    }

    _settingError = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _settingError = false;
        return;
      }

      setState(() {
        _error = error;
      });

      _settingError = false;
    });
  }

  void _retry() {
    ErrorBoundary.clearGlobalError();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _error = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Object? effectiveError = _error;

    if (effectiveError == null) {
      return widget.child;
    }

    final String safeErrorText = PublicFailure.from(
      effectiveError,
      fallback:
          'ChronoSpark recovered the failure. Your saved work is unchanged; retry when ready.',
    ).message;

    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.memoryAmber,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                safeErrorText,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
