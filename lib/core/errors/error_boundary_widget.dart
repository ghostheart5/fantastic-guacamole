import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/material.dart';

/// Wraps a subtree to catch errors surfaced via [captureError].
/// Children can call [ErrorBoundary.of(context)?.captureError(e)] to trigger
/// the fallback UI without crashing the entire app.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({required this.child, super.key});

  final Widget child;

  static ErrorBoundaryState? of(BuildContext context) =>
      context.findAncestorStateOfType<ErrorBoundaryState>();

  @override
  State<ErrorBoundary> createState() => ErrorBoundaryState();
}

class ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  void captureError(Object error, [StackTrace? stack]) {
    Logger.error('ErrorBoundary caught error', error);
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorFallback(onRetry: () => setState(() => _error = null));
    }
    return widget.child;
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.memoryAmber.withValues(alpha: 0.8),
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'An unexpected error occurred in this view.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neonCyan.withValues(alpha: 0.15),
                  foregroundColor: AppColors.neonCyan,
                  side: BorderSide(
                    color: AppColors.neonCyan.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
