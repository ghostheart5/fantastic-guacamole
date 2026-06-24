import 'dart:async';

import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.signInAttempt,
    required this.child,
    this.loading,
    this.errorBuilder,
    this.timeout = const Duration(seconds: 8),
    this.maxRetries = 1,
  }) : assert(maxRetries >= 0, 'maxRetries must be zero or greater.');

  final Future<bool> Function() signInAttempt;
  final Widget child;
  final Widget? loading;
  final Widget Function(BuildContext context, Object error, VoidCallback retry)? errorBuilder;
  final Duration timeout;
  final int maxRetries;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _attemptSignIn();
  }

  Future<void> _attemptSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    int attempt = 0;
    final int retryLimit = widget.maxRetries;

    while (attempt <= retryLimit) {
      try {
        final bool signedIn = await widget.signInAttempt().timeout(widget.timeout);
        if (!mounted) {
          return;
        }
        if (signedIn) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          return;
        }
        _error = Exception('Sign-in attempt returned false.');
        break;
      } on TimeoutException {
        if (attempt == retryLimit) {
          _error = TimeoutException('Sign-in timed out.');
          break;
        }
      } catch (error) {
        _error = error;
        break;
      }
      attempt += 1;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticated = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loading ?? const Center(child: CircularProgressIndicator());
    }

    if (_isAuthenticated) {
      return widget.child;
    }

    final Object error = _error ?? Exception('Authentication failed.');
    return widget.errorBuilder?.call(context, error, _attemptSignIn) ??
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _attemptSignIn, child: const Text('Retry Sign In')),
            ],
          ),
        );
  }
}
