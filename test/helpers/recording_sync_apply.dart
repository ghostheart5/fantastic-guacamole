import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';

enum RecordingSyncApplyMode { success, retryableFailure }

class RecordingSyncApply {
  RecordingSyncApply({this.mode = RecordingSyncApplyMode.success});

  RecordingSyncApplyMode mode;
  final List<SyncOperation> calls = <SyncOperation>[];

  SyncApplyFn get apply => call;

  Future<SyncApplyResult> call(SyncOperation operation) async {
    calls.add(operation);
    return switch (mode) {
      RecordingSyncApplyMode.success => SyncApplyResult.success(),
      RecordingSyncApplyMode.retryableFailure => SyncApplyResult.retryable(
        'Injected remote apply failure.',
      ),
    };
  }
}
