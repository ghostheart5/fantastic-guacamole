import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:flutter/foundation.dart';

@immutable
class LogsState {
  const LogsState({
    required this.entries,
    required this.isLoading,
    this.error,
    this.activeFilter,
  });

  final List<LogEntryEntity> entries;
  final bool isLoading;
  final String? error;
  final String? activeFilter; // null = all, or "task" / "focus" / "system"

  factory LogsState.initial() => const LogsState(entries: [], isLoading: false);

  List<LogEntryEntity> get filtered {
    if (activeFilter == null) return entries;
    return entries
        .where((LogEntryEntity entry) => entry.source == activeFilter)
        .toList();
  }

  LogsState copyWith({
    List<LogEntryEntity>? entries,
    bool? isLoading,
    String? error,
    String? activeFilter,
    bool clearError = false,
    bool clearFilter = false,
  }) {
    return LogsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
    );
  }
}
