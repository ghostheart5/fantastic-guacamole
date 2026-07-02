import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter/services.dart';

class CreatorWorkspaceState {
  const CreatorWorkspaceState({
    required this.tasksEvents,
    required this.goals,
    required this.routines,
    required this.siOutputs,
  });

  final List<String> tasksEvents;
  final List<String> goals;
  final List<String> routines;
  final List<String> siOutputs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tasksEvents': tasksEvents,
      'goals': goals,
      'routines': routines,
      'siOutputs': siOutputs,
    };
  }

  factory CreatorWorkspaceState.fromJson(Map<String, dynamic> json) {
    List<String> toStrings(String key) {
      final dynamic raw = json[key];
      final List<dynamic> values = raw is List<dynamic> ? raw : const <dynamic>[];
      return values.map((dynamic e) => e.toString()).toList();
    }

    return CreatorWorkspaceState(
      tasksEvents: toStrings('tasksEvents'),
      goals: toStrings('goals'),
      routines: toStrings('routines'),
      siOutputs: toStrings('siOutputs'),
    );
  }
}

class TemporalPlannerState {
  const TemporalPlannerState({required this.selectedDay, required this.timelineItems});

  final String selectedDay;
  final List<PlannerTimelineItem> timelineItems;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selectedDay': selectedDay,
      'timelineItems': timelineItems.map((PlannerTimelineItem item) => item.toJson()).toList(),
    };
  }

  factory TemporalPlannerState.fromJson(Map<String, dynamic> json) {
    final dynamic rawTimeline = json['timelineItems'];
    final List<dynamic> raw = rawTimeline is List<dynamic> ? rawTimeline : const <dynamic>[];
    final List<PlannerTimelineItem> parsedItems = raw
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
        .map(PlannerTimelineItem.fromJson)
        .toList();

    final dynamic rawSelectedDay = json['selectedDay'];
    return TemporalPlannerState(
      selectedDay: rawSelectedDay is String ? rawSelectedDay : 'Mon',
      timelineItems: parsedItems,
    );
  }
}

class PlannerTimelineItem {
  const PlannerTimelineItem({
    required this.time,
    required this.title,
    required this.kind,
    required this.colorHex,
  });

  final String time;
  final String title;
  final String kind;
  final String colorHex;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'time': time, 'title': title, 'kind': kind, 'colorHex': colorHex};
  }

  factory PlannerTimelineItem.fromJson(Map<String, dynamic> json) {
    return PlannerTimelineItem(
      time: (json['time'] as String?) ?? '09:00',
      title: (json['title'] as String?) ?? 'Untitled block',
      kind: (json['kind'] as String?) ?? 'Task',
      colorHex: (json['colorHex'] as String?) ?? '0xFF00F0FF',
    );
  }
}

class SIReflectionEntry {
  const SIReflectionEntry({
    required this.note,
    required this.energy,
    required this.emotion,
    required this.timestampUtc,
  });

  final String note;
  final double energy;
  final String emotion;
  final String timestampUtc;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'note': note,
      'energy': energy,
      'emotion': emotion,
      'timestampUtc': timestampUtc,
    };
  }

  factory SIReflectionEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rawEnergy = json['energy'];
    final double energy = switch (rawEnergy) {
      num value => value.toDouble(),
      String value => double.tryParse(value) ?? 0.5,
      _ => 0.5,
    };

    return SIReflectionEntry(
      note: (json['note'] as String?) ?? '',
      energy: energy.clamp(0.0, 1.0),
      emotion: (json['emotion'] as String?) ?? 'neutral',
      timestampUtc: (json['timestampUtc'] as String?) ?? '',
    );
  }
}

class SIWorkspaceState {
  const SIWorkspaceState({
    required this.reflections,
    required this.reflectionEntries,
    required this.stressLevel,
  });

  final List<String> reflections;
  final List<SIReflectionEntry> reflectionEntries;
  final double stressLevel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reflections': reflections,
      'reflectionEntries': reflectionEntries
          .map((SIReflectionEntry entry) => entry.toJson())
          .toList(),
      'stressLevel': stressLevel,
    };
  }

  factory SIWorkspaceState.fromJson(Map<String, dynamic> json) {
    final dynamic rawReflections = json['reflections'];
    final List<dynamic> reflectionsValues = rawReflections is List<dynamic>
        ? rawReflections
        : const <dynamic>[];

    final dynamic rawEntries = json['reflectionEntries'];
    final List<dynamic> entriesValues = rawEntries is List<dynamic>
        ? rawEntries
        : const <dynamic>[];

    final List<SIReflectionEntry> parsedEntries = entriesValues
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
        .map(SIReflectionEntry.fromJson)
        .toList();

    final dynamic rawStress = json['stressLevel'];
    final double stressLevel = switch (rawStress) {
      num value => value.toDouble(),
      String value => double.tryParse(value) ?? 0.34,
      _ => 0.34,
    };

    return SIWorkspaceState(
      reflections: reflectionsValues.map((dynamic e) => e.toString()).toList(),
      reflectionEntries: parsedEntries,
      stressLevel: stressLevel,
    );
  }
}

class WorkspaceStoreService {
  WorkspaceStoreService({required this._store});

  static const String _creatorKey = 'workspace_creator_v1';
  static const String _temporalKey = 'workspace_temporal_v1';
  static const String _siKey = 'workspace_si_v1';
  final SecureStore _store;

  Future<CreatorWorkspaceState> loadCreatorState() async {
    final String? raw = await _store.readString(_creatorKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final Map<String, dynamic>? decoded = _decodeStateMap(raw, storageKey: _creatorKey);
      if (decoded != null) {
        try {
          return CreatorWorkspaceState.fromJson(decoded);
        } on TypeError catch (error) {
          Logger.error('Creator workspace state invalid shape. Re-seeding defaults. $error');
        }
      }
    }

    final CreatorWorkspaceState seeded = await _loadCreatorSeed();
    await saveCreatorState(seeded);
    return seeded;
  }

  Future<void> saveCreatorState(CreatorWorkspaceState state) async {
    await _store.writeString(_creatorKey, jsonEncode(state.toJson()));
  }

  Future<TemporalPlannerState> loadTemporalState() async {
    final String? raw = await _store.readString(_temporalKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final Map<String, dynamic>? decoded = _decodeStateMap(raw, storageKey: _temporalKey);
      if (decoded != null) {
        try {
          return TemporalPlannerState.fromJson(decoded);
        } on TypeError catch (error) {
          Logger.error('Temporal workspace state invalid shape. Re-seeding defaults. $error');
        }
      }
    }

    final TemporalPlannerState seeded = await _loadTemporalSeed();
    await saveTemporalState(seeded);
    return seeded;
  }

  Future<void> saveTemporalState(TemporalPlannerState state) async {
    await _store.writeString(_temporalKey, jsonEncode(state.toJson()));
  }

  Future<SIWorkspaceState> loadSiState() async {
    final String? raw = await _store.readString(_siKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final Map<String, dynamic>? decoded = _decodeStateMap(raw, storageKey: _siKey);
      if (decoded != null) {
        try {
          return SIWorkspaceState.fromJson(decoded);
        } on TypeError catch (error) {
          Logger.error('SI workspace state invalid shape. Re-seeding defaults. $error');
        }
      }
    }

    final SIWorkspaceState seeded = await _loadSiSeed();
    await saveSiState(seeded);
    return seeded;
  }

  Future<void> saveSiState(SIWorkspaceState state) async {
    await _store.writeString(_siKey, jsonEncode(state.toJson()));
  }

  Future<SIWorkspaceState> appendSiReflection({
    required String note,
    required double energy,
    required String emotion,
  }) async {
    final SIWorkspaceState current = await loadSiState();
    final SIReflectionEntry entry = SIReflectionEntry(
      note: note,
      energy: energy.clamp(0.0, 1.0),
      emotion: emotion,
      timestampUtc: DateTime.now().toUtc().toIso8601String(),
    );

    final SIWorkspaceState updated = SIWorkspaceState(
      reflections: <String>[...current.reflections, note],
      reflectionEntries: <SIReflectionEntry>[...current.reflectionEntries, entry],
      stressLevel: current.stressLevel,
    );
    await saveSiState(updated);
    return updated;
  }

  Map<String, dynamic>? _decodeStateMap(String raw, {required String storageKey}) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map<dynamic, dynamic>) {
        return decoded.cast<String, dynamic>();
      }
      Logger.error('Workspace payload at $storageKey is not a JSON object. Re-seeding defaults.');
      return null;
    } on FormatException catch (error) {
      Logger.error('Workspace payload at $storageKey is corrupt JSON. Re-seeding defaults. $error');
      return null;
    }
  }

  Future<CreatorWorkspaceState> _loadCreatorSeed() async {
    try {
      final String content = await rootBundle.loadString('assets/data/creator_seed.json');
      return CreatorWorkspaceState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on Exception {
      return const CreatorWorkspaceState(
        tasksEvents: <String>[],
        goals: <String>[],
        routines: <String>[],
        siOutputs: <String>[],
      );
    }
  }

  Future<TemporalPlannerState> _loadTemporalSeed() async {
    try {
      final String content = await rootBundle.loadString('assets/data/temporal_seed.json');
      return TemporalPlannerState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on Exception {
      return const TemporalPlannerState(selectedDay: 'Mon', timelineItems: <PlannerTimelineItem>[]);
    }
  }

  Future<SIWorkspaceState> _loadSiSeed() async {
    try {
      final String content = await rootBundle.loadString('assets/data/si_seed.json');
      return SIWorkspaceState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on Exception {
      return const SIWorkspaceState(
        reflections: <String>[],
        reflectionEntries: <SIReflectionEntry>[],
        stressLevel: 0.34,
      );
    }
  }
}
