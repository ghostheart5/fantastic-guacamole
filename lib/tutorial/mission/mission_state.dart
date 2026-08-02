import 'package:flutter/foundation.dart';

enum MissionId {
  // Legacy internal name retained for compatibility. This step now means
  // "Create Something" and accepts task, routine, goal, or note creation.
  createFirstGoal,
  configureFirstItem,
  // Legacy compatibility-only step retained so older saved progress can be
  // migrated safely. It is no longer part of required first setup.
  askSmartPlannerQuestion,
  // Reaching Timeline completes the setup flow. It does not require a
  // complete/skip/reschedule Timeline action.
  openTimeline,
  complete,
}

enum MissionStatus { locked, active, completed, dismissed }

@immutable
class MissionStep {
  const MissionStep({required this.id, required this.title});

  final MissionId id;
  final String title;
}

class MissionCatalog {
  const MissionCatalog._();

  static const List<MissionStep> steps = <MissionStep>[
    MissionStep(id: MissionId.createFirstGoal, title: 'Create Something'),
    MissionStep(
      id: MissionId.configureFirstItem,
      title: 'Choose When It Happens',
    ),
    MissionStep(
      id: MissionId.askSmartPlannerQuestion,
      title: 'Optional after setup',
    ),
    MissionStep(id: MissionId.openTimeline, title: 'View Your Timeline'),
    MissionStep(id: MissionId.complete, title: 'Setup complete.'),
  ];

  static const List<MissionId> progression = <MissionId>[
    MissionId.createFirstGoal,
    MissionId.configureFirstItem,
    MissionId.openTimeline,
  ];

  static MissionStep stepFor(MissionId id) {
    return steps.firstWhere((MissionStep step) => step.id == id);
  }
}

@immutable
class MissionState {
  const MissionState({
    required this.statuses,
    required this.activeMissionId,
    required this.started,
    required this.finished,
  });

  final Map<MissionId, MissionStatus> statuses;
  final MissionId? activeMissionId;
  final bool started;
  final bool finished;

  factory MissionState.initial() {
    return const MissionState(
      statuses: <MissionId, MissionStatus>{
        MissionId.createFirstGoal: MissionStatus.active,
        MissionId.configureFirstItem: MissionStatus.locked,
        MissionId.askSmartPlannerQuestion: MissionStatus.locked,
        MissionId.openTimeline: MissionStatus.locked,
        MissionId.complete: MissionStatus.locked,
      },
      activeMissionId: MissionId.createFirstGoal,
      started: true,
      finished: false,
    );
  }

  MissionStep? get activeMission {
    final MissionId? id = activeMissionId;
    if (id == null) {
      return null;
    }
    return MissionCatalog.stepFor(id);
  }

  MissionStatus statusOf(MissionId id) {
    return statuses[id] ?? MissionStatus.locked;
  }

  bool get isVisible => activeMissionId != null && !finished;

  bool get isCompletionBannerActive {
    return activeMissionId == MissionId.complete &&
        statusOf(MissionId.complete) == MissionStatus.active;
  }

  MissionState copyWith({
    Map<MissionId, MissionStatus>? statuses,
    MissionId? activeMissionId,
    bool? started,
    bool? finished,
  }) {
    return MissionState(
      statuses: statuses ?? this.statuses,
      activeMissionId: activeMissionId,
      started: started ?? this.started,
      finished: finished ?? this.finished,
    );
  }

  MissionState completeAndAdvance(MissionId id) {
    final MissionStatus currentStatus = statusOf(id);
    if (currentStatus != MissionStatus.active) {
      return this;
    }

    final Map<MissionId, MissionStatus> next =
        Map<MissionId, MissionStatus>.from(statuses);
    next[id] = MissionStatus.completed;

    if (id == MissionId.openTimeline) {
      // First setup completes by reaching Timeline successfully.
      next[MissionId.complete] = MissionStatus.active;
      return copyWith(statuses: next, activeMissionId: MissionId.complete);
    }

    final int index = MissionCatalog.progression.indexOf(id);
    if (index >= 0 && index + 1 < MissionCatalog.progression.length) {
      final MissionId nextId = MissionCatalog.progression[index + 1];
      next[nextId] = MissionStatus.active;
      return copyWith(statuses: next, activeMissionId: nextId);
    }

    return copyWith(statuses: next, activeMissionId: null);
  }

  MissionState dismissCompletionBanner() {
    if (!isCompletionBannerActive) {
      return this;
    }
    final Map<MissionId, MissionStatus> next =
        Map<MissionId, MissionStatus>.from(statuses);
    next[MissionId.complete] = MissionStatus.dismissed;
    return copyWith(statuses: next, activeMissionId: null, finished: true);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'started': started,
      'finished': finished,
      'activeMissionId': activeMissionId?.name,
      'statuses': <String, String>{
        for (final MapEntry<MissionId, MissionStatus> entry in statuses.entries)
          entry.key.name: entry.value.name,
      },
    };
  }

  factory MissionState.fromJson(Map<String, Object?> json) {
    final Object? statusesRaw = json['statuses'];
    final Map<MissionId, MissionStatus> statuses = <MissionId, MissionStatus>{
      MissionId.createFirstGoal: MissionStatus.active,
      MissionId.configureFirstItem: MissionStatus.locked,
      MissionId.askSmartPlannerQuestion: MissionStatus.locked,
      MissionId.openTimeline: MissionStatus.locked,
      MissionId.complete: MissionStatus.locked,
    };

    if (statusesRaw is Map) {
      for (final MapEntry<Object?, Object?> entry in statusesRaw.entries) {
        final String idName = entry.key?.toString() ?? '';
        final String statusName = entry.value?.toString() ?? '';

        final MissionId? id = _missionIdFromStoredName(idName);

        final MissionStatus? status = MissionStatus.values
            .where((MissionStatus candidate) => candidate.name == statusName)
            .cast<MissionStatus?>()
            .firstWhere(
              (MissionStatus? value) => value != null,
              orElse: () => null,
            );

        if (id != null && status != null) {
          statuses[id] = status;
        }
      }
    }

    final String? activeName = json['activeMissionId'] as String?;
    final MissionId? activeMissionId = _missionIdFromStoredName(activeName);

    final bool started = json['started'] == true;
    final bool finished = json['finished'] == true;

    final _MissionStateCompatibility compatibility =
        _normalizeLegacySmartPlannerStep(
          statuses: statuses,
          activeMissionId: activeMissionId,
        );

    return MissionState(
      statuses: compatibility.statuses,
      activeMissionId: compatibility.activeMissionId,
      started: started,
      finished: finished,
    );
  }

  static _MissionStateCompatibility _normalizeLegacySmartPlannerStep({
    required Map<MissionId, MissionStatus> statuses,
    required MissionId? activeMissionId,
  }) {
    final Map<MissionId, MissionStatus> normalizedStatuses =
        Map<MissionId, MissionStatus>.from(statuses);

    final MissionStatus smartPlannerStatus =
        normalizedStatuses[MissionId.askSmartPlannerQuestion] ??
        MissionStatus.locked;
    MissionId? normalizedActiveMissionId = activeMissionId;

    if (smartPlannerStatus == MissionStatus.active ||
        activeMissionId == MissionId.askSmartPlannerQuestion) {
      normalizedStatuses[MissionId.askSmartPlannerQuestion] =
          MissionStatus.completed;

      if (normalizedStatuses[MissionId.openTimeline] ==
          MissionStatus.completed) {
        normalizedStatuses[MissionId.complete] = MissionStatus.active;
      } else {
        normalizedStatuses[MissionId.openTimeline] = MissionStatus.active;
      }

      normalizedActiveMissionId =
          normalizedStatuses[MissionId.openTimeline] == MissionStatus.completed
          ? MissionId.complete
          : MissionId.openTimeline;
    }

    return _MissionStateCompatibility(
      statuses: normalizedStatuses,
      activeMissionId: normalizedActiveMissionId,
    );
  }

  static MissionId? _missionIdFromStoredName(String? storedName) {
    if (storedName == null || storedName.trim().isEmpty) {
      return null;
    }
    final String normalized = storedName.trim();
    if (normalized == 'openActionHub') {
      return MissionId.configureFirstItem;
    }
    return MissionId.values
        .where((MissionId candidate) => candidate.name == normalized)
        .cast<MissionId?>()
        .firstWhere((MissionId? value) => value != null, orElse: () => null);
  }
}

class _MissionStateCompatibility {
  const _MissionStateCompatibility({
    required this.statuses,
    required this.activeMissionId,
  });

  final Map<MissionId, MissionStatus> statuses;
  final MissionId? activeMissionId;
}
