import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'operation_cancellation.dart';

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
      return (json[key] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList();
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
    final List<dynamic> raw = json['timelineItems'] as List<dynamic>? ?? const <dynamic>[];
    return TemporalPlannerState(
      selectedDay: (json['selectedDay'] as String?) ?? 'Mon',
      timelineItems: raw
          .map((dynamic e) => PlannerTimelineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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

class SIWorkspaceState {
  const SIWorkspaceState({required this.reflections, required this.stressLevel});

  final List<String> reflections;
  final double stressLevel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'reflections': reflections, 'stressLevel': stressLevel};
  }

  factory SIWorkspaceState.fromJson(Map<String, dynamic> json) {
    return SIWorkspaceState(
      reflections: (json['reflections'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      stressLevel: (json['stressLevel'] as num?)?.toDouble() ?? 0.34,
    );
  }
}

class WorkspaceStoreService {
  static const String _creatorKey = 'workspace_creator_v1';
  static const String _temporalKey = 'workspace_temporal_v1';
  static const String _siKey = 'workspace_si_v1';

  Future<CreatorWorkspaceState> loadCreatorState({CancellationToken? cancellationToken}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? raw = prefs.getString(_creatorKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return CreatorWorkspaceState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final CreatorWorkspaceState seeded = await _loadCreatorSeed(cancellationToken: cancellationToken);
    await saveCreatorState(seeded, cancellationToken: cancellationToken);
    return seeded;
  }

  Future<void> saveCreatorState(
    CreatorWorkspaceState state, {
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();

    await prefs.setString(_creatorKey, jsonEncode(state.toJson()));
  }

  Future<TemporalPlannerState> loadTemporalState({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? raw = prefs.getString(_temporalKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return TemporalPlannerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final TemporalPlannerState seeded = await _loadTemporalSeed(
      cancellationToken: cancellationToken,
    );
    await saveTemporalState(seeded, cancellationToken: cancellationToken);
    return seeded;
  }

  Future<void> saveTemporalState(
    TemporalPlannerState state, {
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();

    await prefs.setString(_temporalKey, jsonEncode(state.toJson()));
  }

  Future<SIWorkspaceState> loadSiState({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? raw = prefs.getString(_siKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return SIWorkspaceState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final SIWorkspaceState seeded = await _loadSiSeed(cancellationToken: cancellationToken);
    await saveSiState(seeded, cancellationToken: cancellationToken);
    return seeded;
  }

  Future<void> saveSiState(SIWorkspaceState state, {CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();

    await prefs.setString(_siKey, jsonEncode(state.toJson()));
  }

  Future<CreatorWorkspaceState> _loadCreatorSeed({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    try {
      final String content = await rootBundle.loadString('assets/data/creator_seed.json');
      cancellationToken.throwIfCancelled();
      return CreatorWorkspaceState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return const CreatorWorkspaceState(
        tasksEvents: <String>[],
        goals: <String>[],
        routines: <String>[],
        siOutputs: <String>[],
      );
    }
  }

  Future<TemporalPlannerState> _loadTemporalSeed({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    try {
      final String content = await rootBundle.loadString('assets/data/temporal_seed.json');
      cancellationToken.throwIfCancelled();
      return TemporalPlannerState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return const TemporalPlannerState(selectedDay: 'Mon', timelineItems: <PlannerTimelineItem>[]);
    }
  }

  Future<SIWorkspaceState> _loadSiSeed({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    try {
      final String content = await rootBundle.loadString('assets/data/si_seed.json');
      cancellationToken.throwIfCancelled();
      return SIWorkspaceState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return const SIWorkspaceState(reflections: <String>[], stressLevel: 0.34);
    }
  }
}
