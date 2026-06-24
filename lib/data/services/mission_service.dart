import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_model.dart';
import '../models/task_model.dart';
import 'operation_cancellation.dart';

class MissionService {
  static const String _missionsKey = 'planner_missions_v1';

  static const List<MissionModel> _defaultMissions = <MissionModel>[
    MissionModel(
      id: 'm1',
      name: 'Launch Sprint',
      tasks: <TaskModel>[
        TaskModel(id: 't1', title: 'Prototype UI'),
        TaskModel(id: 't2', title: 'Define milestones'),
      ],
    ),
    MissionModel(
      id: 'm2',
      name: 'Focus Rebuild',
      tasks: <TaskModel>[TaskModel(id: 't3', title: 'Timebox deep work')],
    ),
  ];

  Future<List<MissionModel>> loadMissions({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();

    final String? raw = prefs.getString(_missionsKey);
    if (raw == null || raw.trim().isEmpty) {
      await saveMissions(_defaultMissions, cancellationToken: cancellationToken);
      return _defaultMissions;
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => MissionModel.fromJson(e))
        .toList();
  }

  Future<void> saveMissions(
    List<MissionModel> missions, {
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();

    final String payload = jsonEncode(
      missions.map((MissionModel mission) => mission.toJson()).toList(),
    );
    await prefs.setString(_missionsKey, payload);
  }
}
