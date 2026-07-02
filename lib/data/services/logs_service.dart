import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class ChronoLogsPayload {
  final List<String> completedTasks;
  final List<String> pastMissions;
  final List<String> pastSchedules;
  final List<String> notes;
  final List<String> dailyLogs;
  final List<String> archivedEvents;
  final List<String> oldRoutines;
  final List<String> archives;

  const ChronoLogsPayload({
    required this.completedTasks,
    required this.pastMissions,
    required this.pastSchedules,
    required this.notes,
    required this.dailyLogs,
    required this.archivedEvents,
    required this.oldRoutines,
    required this.archives,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'completedTasks': completedTasks,
    'pastMissions': pastMissions,
    'pastSchedules': pastSchedules,
    'notes': notes,
    'dailyLogs': dailyLogs,
    'archivedEvents': archivedEvents,
    'oldRoutines': oldRoutines,
    'archives': archives,
  };

  factory ChronoLogsPayload.fromJson(Map<String, dynamic> json) {
    List<String> toStrings(dynamic value) {
      if (value is List<dynamic>) {
        return value.map((dynamic e) => e.toString()).toList();
      }
      return <String>[];
    }

    return ChronoLogsPayload(
      completedTasks: toStrings(json['completedTasks']),
      pastMissions: toStrings(json['pastMissions']),
      pastSchedules: toStrings(json['pastSchedules']),
      notes: toStrings(json['notes']),
      dailyLogs: toStrings(json['dailyLogs']),
      archivedEvents: toStrings(json['archivedEvents']),
      oldRoutines: toStrings(json['oldRoutines']),
      archives: toStrings(json['archives']),
    );
  }
}

class ChronoLogsService {
  ChronoLogsService({required this._store});

  static const String _key = 'chronologs_payload_v1';
  final SecureStore _store;

  static const ChronoLogsPayload _defaultPayload = ChronoLogsPayload(
    completedTasks: <String>[
      'Finalized mission brief',
      'Completed deep work sprint',
      'Closed tactical planning loop',
    ],
    pastMissions: <String>['Mission Blackglass', 'Mission Morning Surge', 'Mission Iron Focus'],
    pastSchedules: <String>['2026-06-15: 6 focused blocks', '2026-06-16: 5 focused blocks'],
    notes: <String>[
      'Energy peaks between 09:00 and 12:00.',
      'Avoid stacking two heavy creative blocks back to back.',
    ],
    dailyLogs: <String>[
      '06:30 - Booted command deck and loaded tactical plan.',
      '10:10 - Completed two mission nodes ahead of schedule.',
    ],
    archivedEvents: <String>[
      'Redacted Event 07A sealed into vault.',
      'Overload incident 12F archived.',
    ],
    oldRoutines: <String>['Legacy Dawn Sprint (retired)', 'Night Compression Loop (retired)'],
    archives: <String>['Q2 Mission Archive', 'April Tactical Snapshot'],
  );

  Future<ChronoLogsPayload> load() async {
    final String? raw = await _store.readString(_key);
    if (raw == null || raw.trim().isEmpty) {
      await save(_defaultPayload);
      return _defaultPayload;
    }

    try {
      final Map<String, dynamic> json = (jsonDecode(raw) as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      return ChronoLogsPayload.fromJson(json);
    } on FormatException catch (error) {
      Logger.error('Chronolog payload corrupt. Resetting defaults. $error');
      await save(_defaultPayload);
      return _defaultPayload;
    } on TypeError catch (error) {
      Logger.error('Chronolog payload invalid shape. Resetting defaults. $error');
      await save(_defaultPayload);
      return _defaultPayload;
    }
  }

  Future<void> save(ChronoLogsPayload payload) async {
    await _store.writeString(_key, jsonEncode(payload.toJson()));
  }

  Future<void> addCompletedTask(String taskLine) async {
    final String line = taskLine.trim();
    if (line.isEmpty) {
      return;
    }

    final ChronoLogsPayload current = await load();
    if (current.completedTasks.contains(line)) {
      return;
    }

    final ChronoLogsPayload next = ChronoLogsPayload(
      completedTasks: <String>[line, ...current.completedTasks],
      pastMissions: current.pastMissions,
      pastSchedules: current.pastSchedules,
      notes: current.notes,
      dailyLogs: <String>[
        '${DateTime.now().toIso8601String()} :: Completed $line',
        ...current.dailyLogs,
      ],
      archivedEvents: current.archivedEvents,
      oldRoutines: current.oldRoutines,
      archives: current.archives,
    );
    await save(next);
  }
}
