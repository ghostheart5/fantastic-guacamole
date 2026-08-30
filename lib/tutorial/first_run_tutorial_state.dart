import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CreatorTutorialStep { title, priority, schedule, save, confirm }

class CreatorTutorialDraftState {
  const CreatorTutorialDraftState({
    this.hasTitle = false,
    this.hasChosenPriority = false,
    this.hasSchedule = false,
  });

  final bool hasTitle;
  final bool hasChosenPriority;
  final bool hasSchedule;

  CreatorTutorialDraftState copyWith({
    bool? hasTitle,
    bool? hasChosenPriority,
    bool? hasSchedule,
  }) {
    return CreatorTutorialDraftState(
      hasTitle: hasTitle ?? this.hasTitle,
      hasChosenPriority: hasChosenPriority ?? this.hasChosenPriority,
      hasSchedule: hasSchedule ?? this.hasSchedule,
    );
  }
}

final creatorTutorialDraftProvider =
    NotifierProvider<CreatorTutorialDraftNotifier, CreatorTutorialDraftState>(
      CreatorTutorialDraftNotifier.new,
    );

final creatorTutorialFormControllerProvider =
    Provider<CreatorTutorialFormController>(
      (Ref ref) => CreatorTutorialFormController(),
    );

final tutorialInteractionPausedProvider =
    NotifierProvider<TutorialInteractionPausedNotifier, bool>(
      TutorialInteractionPausedNotifier.new,
    );

final timelineTutorialEvidenceProvider =
    NotifierProvider<TimelineTutorialEvidenceNotifier, String?>(
      TimelineTutorialEvidenceNotifier.new,
    );

class TutorialInteractionPausedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class TimelineTutorialEvidenceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setTaskId(String? taskId) {
    final String? normalized = taskId?.trim();
    state = normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class CreatorTutorialFormController {
  Future<void> Function()? _submit;

  void attach(Future<void> Function() submit) => _submit = submit;

  void detach(Future<void> Function() submit) {
    if (identical(_submit, submit)) _submit = null;
  }

  Future<void> submit() async {
    await _submit?.call();
  }
}

class CreatorTutorialDraftNotifier extends Notifier<CreatorTutorialDraftState> {
  @override
  CreatorTutorialDraftState build() => const CreatorTutorialDraftState();

  void setHasTitle(bool value) => state = state.copyWith(hasTitle: value);

  void markPriorityChosen() => state = state.copyWith(hasChosenPriority: true);

  void setHasSchedule(bool value) => state = state.copyWith(hasSchedule: value);

  void reset() => state = const CreatorTutorialDraftState();
}

abstract final class FirstRunTutorialTargets {
  static final GlobalKey creatorTitle = GlobalKey(
    debugLabel: 'creator-tutorial-title',
  );
  static final GlobalKey creatorPriority = GlobalKey(
    debugLabel: 'creator-tutorial-priority',
  );
  static final GlobalKey creatorSchedule = GlobalKey(
    debugLabel: 'creator-tutorial-schedule',
  );
  static final GlobalKey creatorSave = GlobalKey(
    debugLabel: 'creator-tutorial-save',
  );
  static final GlobalKey creatorConfirm = GlobalKey(
    debugLabel: 'creator-tutorial-confirm',
  );
  static final GlobalKey timelineEvidence = GlobalKey(
    debugLabel: 'timeline-tutorial-evidence',
  );
}
