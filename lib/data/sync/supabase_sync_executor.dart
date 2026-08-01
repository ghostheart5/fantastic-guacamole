import 'package:fantastic_guacamole/data/remote/goals_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habits_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/settings_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/tasks_remote_gateway.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';

class SupabaseSyncExecutor {
  const SupabaseSyncExecutor({
    required this._tasksGateway,
    required this._goalsGateway,
    required this._habitsGateway,
    required this._settingsGateway,
  });

  final TasksRemoteGateway _tasksGateway;
  final GoalsRemoteGateway _goalsGateway;
  final HabitsRemoteGateway _habitsGateway;
  final SettingsRemoteGateway _settingsGateway;

  Future<SyncApplyResult> apply(SyncOperation operation) async {
    try {
      switch (operation.tableName) {
        case 'tasks':
          return _applyForTasks(operation);
        case 'goals':
          return _applyForGoals(operation);
        case 'habits':
          return _applyForHabits(operation);
        case 'settings':
          return _applyForSettings(operation);
        default:
          return SyncApplyResult.fatal(
            'Unsupported sync table: ${operation.tableName}',
          );
      }
    } on Object catch (error) {
      final String message = error.toString();
      if (_isRetryable(message)) {
        return SyncApplyResult.retryable(message);
      }
      return SyncApplyResult.fatal(message);
    }
  }

  Future<SyncApplyResult> _applyForTasks(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.delete) {
      await _tasksGateway.softDelete(
        id: operation.recordId,
        userId: operation.userId,
      );
      return SyncApplyResult.success();
    }
    await _tasksGateway.upsert(row: operation.payload);
    return SyncApplyResult.success();
  }

  Future<SyncApplyResult> _applyForGoals(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.delete) {
      await _goalsGateway.softDelete(
        id: operation.recordId,
        userId: operation.userId,
      );
      return SyncApplyResult.success();
    }
    await _goalsGateway.upsert(row: operation.payload);
    return SyncApplyResult.success();
  }

  Future<SyncApplyResult> _applyForHabits(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.delete) {
      await _habitsGateway.softDelete(
        id: operation.recordId,
        userId: operation.userId,
      );
      return SyncApplyResult.success();
    }
    await _habitsGateway.upsert(row: operation.payload);
    return SyncApplyResult.success();
  }

  Future<SyncApplyResult> _applyForSettings(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.delete) {
      await _settingsGateway.softDelete(
        id: operation.recordId,
        userId: operation.userId,
      );
      return SyncApplyResult.success();
    }
    await _settingsGateway.upsert(row: operation.payload);
    return SyncApplyResult.success();
  }

  bool _isRetryable(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('429') ||
        lower.contains('503') ||
        lower.contains('504');
  }
}
