part of 'app_bootstrap.dart';

class StartupCancellationToken {
  bool _isCancelled = false;
  final Completer<void> _sourceSettled = Completer<void>();

  bool get isCancelled => _isCancelled;
  bool get isSourceSettled => _sourceSettled.isCompleted;
  Future<void> get whenSourceSettled => _sourceSettled.future;

  void cancel() {
    _isCancelled = true;
  }

  void _markSourceSettled() {
    if (!_sourceSettled.isCompleted) {
      _sourceSettled.complete();
    }
  }
}

class StartupBootstrapResult {
  const StartupBootstrapResult({
    required this.hasOnboarded,
    required this.hasSeenWelcome,
    required this.startupError,
    required this.productionReadinessBlocked,
  });

  final bool hasOnboarded;
  final bool hasSeenWelcome;
  final String? startupError;
  final bool productionReadinessBlocked;
}

const StartupBootstrapResult _cancelledStartupResult = StartupBootstrapResult(
  hasOnboarded: false,
  hasSeenWelcome: false,
  startupError: null,
  productionReadinessBlocked: false,
);

class PrefsLoadResult {
  const PrefsLoadResult({
    required this.hasOnboarded,
    required this.hasSeenWelcome,
    required this.issue,
  });

  final bool hasOnboarded;
  final bool hasSeenWelcome;
  final String? issue;
}

const PrefsLoadResult _cancelledPrefsLoadResult = PrefsLoadResult(
  hasOnboarded: false,
  hasSeenWelcome: false,
  issue: null,
);
