class SyncApplyResult {
  const SyncApplyResult({
    required this.ok,
    required this.error,
    required this.shouldRetry,
  });

  final bool ok;
  final String? error;
  final bool shouldRetry;

  factory SyncApplyResult.success() {
    return const SyncApplyResult(ok: true, error: null, shouldRetry: false);
  }

  factory SyncApplyResult.retryable(String error) {
    return SyncApplyResult(ok: false, error: error, shouldRetry: true);
  }

  factory SyncApplyResult.fatal(String error) {
    return SyncApplyResult(ok: false, error: error, shouldRetry: false);
  }
}
