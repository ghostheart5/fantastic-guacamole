import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({required this.child, super.key});

  final Widget child;
  static final ValueNotifier<Object?> _globalErrorNotifier =
      ValueNotifier<Object?>(null);

  static ErrorBoundaryState? of(BuildContext context) =>
      context.findAncestorStateOfType<ErrorBoundaryState>();

  static ValueListenable<Object?> get globalErrorListenable =>
      _globalErrorNotifier;

  static void reportGlobalError(Object error, [StackTrace? stackTrace]) {
    Logger.error('Global error captured', error);
    _globalErrorNotifier.value = error;
  }

  static void clearGlobalError() {
    _globalErrorNotifier.value = null;
  }

  @override
  State<ErrorBoundary> createState() => ErrorBoundaryState();
}

class ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  void captureError(Object error, [StackTrace? stackTrace]) {
    Logger.error('ErrorBoundary caught error', error);
    ErrorBoundary.reportGlobalError(error, stackTrace);
    if (mounted) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: ErrorBoundary.globalErrorListenable,
      builder: (BuildContext context, Object? globalError, Widget? child) {
        final Object? effectiveError = _error ?? globalError;
        if (effectiveError == null) {
          return widget.child;
        }

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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      ErrorBoundary.clearGlobalError();
                      setState(() => _error = null);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
