import 'package:flutter/foundation.dart';

@immutable
class TutorialProgress {
  const TutorialProgress({
    this.completedStepIds = const <String>{},
    this.dismissedStepIds = const <String>{},
    this.skippedForeverStepIds = const <String>{},
    this.started = false,
    this.hasSeenIntro = false,
    this.contentVersion = 1,
  });

  final Set<String> completedStepIds;
  final Set<String> dismissedStepIds;
  final Set<String> skippedForeverStepIds;

  final bool started;
  final bool hasSeenIntro;
  final int contentVersion;

  bool isStepCompleted(String stepId) {
    return completedStepIds.contains(stepId);
  }

  bool isStepDismissed(String stepId) {
    return dismissedStepIds.contains(stepId) ||
        skippedForeverStepIds.contains(stepId);
  }

  bool isStepSkippedForever(String stepId) {
    return skippedForeverStepIds.contains(stepId);
  }

  bool get hasCompletedAllSteps =>
      completedStepIds.isNotEmpty &&
      dismissedStepIds.isEmpty &&
      skippedForeverStepIds.isEmpty;

  int get completedCount => completedStepIds.length;

  int get dismissedCount => dismissedStepIds.length;

  int get skippedForeverCount => skippedForeverStepIds.length;

  double completionRatio(int totalSteps) {
    if (totalSteps <= 0) {
      return 0.0;
    }

    return completedStepIds.length / totalSteps;
  }

  TutorialProgress copyWith({
    Set<String>? completedStepIds,
    Set<String>? dismissedStepIds,
    Set<String>? skippedForeverStepIds,
    bool? started,
    bool? hasSeenIntro,
    int? contentVersion,
  }) {
    return TutorialProgress(
      completedStepIds: completedStepIds ?? this.completedStepIds,
      dismissedStepIds: dismissedStepIds ?? this.dismissedStepIds,
      skippedForeverStepIds:
          skippedForeverStepIds ?? this.skippedForeverStepIds,
      started: started ?? this.started,
      hasSeenIntro: hasSeenIntro ?? this.hasSeenIntro,
      contentVersion: contentVersion ?? this.contentVersion,
    );
  }

  TutorialProgress start({required int targetVersion}) {
    return copyWith(started: true, contentVersion: targetVersion);
  }

  TutorialProgress markCompleted(String stepId) {
    final updatedDismissed = <String>{...dismissedStepIds}..remove(stepId);

    final updatedForever = <String>{...skippedForeverStepIds}..remove(stepId);

    return copyWith(
      completedStepIds: <String>{...completedStepIds, stepId},
      dismissedStepIds: updatedDismissed,
      skippedForeverStepIds: updatedForever,
      started: true,
    );
  }

  TutorialProgress skipStep(String stepId) {
    return copyWith(
      dismissedStepIds: <String>{...dismissedStepIds, stepId},
      started: true,
    );
  }

  TutorialProgress skipForever(String stepId) {
    final updatedDismissed = <String>{...dismissedStepIds}..remove(stepId);

    return copyWith(
      dismissedStepIds: updatedDismissed,
      skippedForeverStepIds: <String>{...skippedForeverStepIds, stepId},
      started: true,
    );
  }

  TutorialProgress revealStep(String stepId) {
    final updatedDismissed = <String>{...dismissedStepIds}..remove(stepId);

    final updatedForever = <String>{...skippedForeverStepIds}..remove(stepId);

    return copyWith(
      dismissedStepIds: updatedDismissed,
      skippedForeverStepIds: updatedForever,
    );
  }

  TutorialProgress markIntroSeen() {
    return copyWith(hasSeenIntro: true);
  }

  TutorialProgress reset({required int targetVersion}) {
    return TutorialProgress(
      started: false,
      hasSeenIntro: false,
      contentVersion: targetVersion,
    );
  }

  TutorialProgress applyContentVersion(int targetVersion) {
    if (contentVersion == targetVersion) {
      return this;
    }

    return TutorialProgress(
      started: false,
      hasSeenIntro: hasSeenIntro,
      contentVersion: targetVersion,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'completed': completedStepIds.toList(growable: false),
      'dismissed': dismissedStepIds.toList(growable: false),
      'skippedForever': skippedForeverStepIds.toList(growable: false),
      'started': started,
      'introSeen': hasSeenIntro,
      'contentVersion': contentVersion,
    };
  }

  factory TutorialProgress.fromJson(Map<String, Object?> json) {
    final completed = (json['completed'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toSet();

    final dismissed = (json['dismissed'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toSet();

    final skippedForever =
        (json['skippedForever'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toSet();

    final started = json['started'] == true;

    final introSeen = json['introSeen'] == true;

    final contentVersion = (json['contentVersion'] as num?)?.toInt() ?? 1;

    return TutorialProgress(
      completedStepIds: completed,
      dismissedStepIds: dismissed,
      skippedForeverStepIds: skippedForever,
      started: started,
      hasSeenIntro: introSeen,
      contentVersion: contentVersion,
    );
  }

  @override
  String toString() {
    return 'TutorialProgress('
        'completed: ${completedStepIds.length}, '
        'dismissed: ${dismissedStepIds.length}, '
        'skippedForever: ${skippedForeverStepIds.length}, '
        'started: $started, '
        'hasSeenIntro: $hasSeenIntro, '
        'contentVersion: $contentVersion'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TutorialProgress &&
            setEquals(completedStepIds, other.completedStepIds) &&
            setEquals(dismissedStepIds, other.dismissedStepIds) &&
            setEquals(skippedForeverStepIds, other.skippedForeverStepIds) &&
            started == other.started &&
            hasSeenIntro == other.hasSeenIntro &&
            contentVersion == other.contentVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(completedStepIds),
      Object.hashAll(dismissedStepIds),
      Object.hashAll(skippedForeverStepIds),
      started,
      hasSeenIntro,
      contentVersion,
    );
  }
}
