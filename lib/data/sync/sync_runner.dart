import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';

typedef SyncApplyFn = Future<SyncApplyResult> Function(SyncOperation operation);

class SyncRunner {
  SyncRunner({
    required this.queueStore,
    required this.applyFn,
    DateTime Function()? now,
  }) : now = now ?? (() => DateTime.now().toUtc());

  final SyncQueueStoreContract queueStore;
  final SyncApplyFn applyFn;
  final DateTime Function() now;

  bool _isRunning = false;

  Future<void> runOnce() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    try {
      final List<SyncOperation> operations = await queueStore.readAll();
      for (final SyncOperation operation in operations) {
        if (!_isReady(operation)) {
          continue;
        }

        final SyncApplyResult result = await applyFn(operation);
        if (result.ok) {
          await queueStore.removeById(operation.operationId);
          continue;
        }

        if (!result.shouldRetry) {
          await queueStore.update(
            operation.copyWith(
              retryCount: operation.retryCount + 1,
              lastError: result.error,
              nextRetryAtUtc: null,
            ),
          );
          continue;
        }

        final int retryCount = operation.retryCount + 1;
        await queueStore.update(
          operation.copyWith(
            retryCount: retryCount,
            lastError: result.error,
            nextRetryAtUtc: now().add(_retryBackoff(retryCount)),
          ),
        );
      }
    } finally {
      _isRunning = false;
    }
  }

  bool _isReady(SyncOperation operation) {
    final DateTime? nextRetry = operation.nextRetryAtUtc;
    if (nextRetry == null) {
      return true;
    }
    return !nextRetry.isAfter(now());
  }

  Duration _retryBackoff(int retryCount) {
    final int seconds = (1 << retryCount).clamp(2, 300);
    return Duration(seconds: seconds);
  }
}
