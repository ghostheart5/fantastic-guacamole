import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/usecases/add_log_entry.dart';
import 'package:fantastic_guacamole/domain/usecases/get_logs.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final getLogsProvider = Provider<GetLogs>(
  (Ref ref) => GetLogs(ref.read(logRepositoryProvider)),
);

final addLogEntryProvider = Provider<AddLogEntry>(
  (Ref ref) => AddLogEntry(ref.read(logRepositoryProvider)),
);

final logsActionsProvider = Provider<LogsActions>((Ref ref) {
  return LogsActions(ref);
});

final logsProvider = NotifierProvider<LogsController, LogsState>(
  LogsController.new,
);

class LogsActions {
  const LogsActions(this._ref);

  final Ref _ref;

  Future<void> addEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) {
    return _ref
        .read(logsProvider.notifier)
        .add(
          source: source,
          message: message,
          id: id,
          timestamp: timestamp,
          updateInsights: updateInsights,
          syncSoulMap: syncSoulMap,
        );
  }

  Future<void> addStandaloneEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) {
    return addEntry(
      source: source,
      message: message,
      id: id,
      timestamp: timestamp,
    );
  }

  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) {
    return _ref
        .read(logsProvider.notifier)
        .add(
          source: source,
          message: message,
          id: id,
          timestamp: timestamp,
          syncTimeline: false,
          refreshCoach: false,
          updateInsights: false,
          syncSoulMap: false,
        );
  }

  Future<void> addCompletedTask({
    required String task,
    bool mirrored = false,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) {
    if (mirrored) {
      return _ref
          .read(logsProvider.notifier)
          .addCompletedTask(
            task,
            syncTimeline: false,
            refreshCoach: false,
            updateInsights: false,
            syncSoulMap: false,
          );
    }
    return _ref
        .read(logsProvider.notifier)
        .addCompletedTask(
          task,
          updateInsights: updateInsights,
          syncSoulMap: syncSoulMap,
        );
  }
}

class LogsController extends Notifier<LogsState> {
  @override
  LogsState build() {
    Future<void>.microtask(load);
    return LogsState.initial().copyWith(isLoading: true);
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<LogEntryEntity> entries = await ref.read(getLogsProvider)();
      if (!ref.mounted) return;
      state = state.copyWith(entries: entries, isLoading: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> add({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool syncTimeline = true,
    bool refreshCoach = true,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) async {
    final String normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }
    final DateTime occurredAt = timestamp ?? DateTime.now();
    final LogEntryEntity entry = LogEntryEntity(
      id: id ?? 'log-${occurredAt.microsecondsSinceEpoch}',
      message: normalizedMessage,
      source: source,
      timestamp: occurredAt,
    );
    await ref.read(addLogEntryProvider)(entry);
    state = state.copyWith(
      entries: <LogEntryEntity>[
        entry,
        ...state.entries.where(
          (LogEntryEntity current) => current.id != entry.id,
        ),
      ],
      isLoading: false,
      clearError: true,
    );

    if (syncTimeline) {
      await ref
          .read(timelineActionsProvider)
          .addMirroredEvent(
            TimelineEventEntity(
              id: 'timeline-${entry.id}',
              type: TimelineEventType.reflection,
              title: 'Log Added',
              detail: normalizedMessage,
              timestamp: occurredAt,
            ),
          );
    }
    if (updateInsights) {
      ref.invalidate(insightsBundleProvider);
    }
    if (syncSoulMap) {
      ref.invalidate(soulStateProvider);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
    }

    ref
        .read(eventBusProvider)
        .emit(
          LogLifecycleEvent(
            logId: entry.id,
            source: source,
            message: normalizedMessage,
          ),
        );
  }

  Future<void> addCompletedTask(
    String task, {
    bool syncTimeline = true,
    bool refreshCoach = true,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) {
    return add(
      source: 'completed_task',
      message: task,
      syncTimeline: syncTimeline,
      refreshCoach: refreshCoach,
      updateInsights: updateInsights,
      syncSoulMap: syncSoulMap,
    );
  }

  void setFilter(String? source) {
    state = state.copyWith(activeFilter: source, clearFilter: source == null);
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking log writes if coach refresh fails.
    }
  }
}
