import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GuidanceLessonId {
  createFirstItem,
  scheduleFirstItem,
  reviewTimeline,
  nexus,
  smartPlanner,
  timelineExecution,
  siConsole,
  trajectoryEngine,
  progression,
}

@immutable
class GuidanceLesson {
  const GuidanceLesson({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.actionLabel,
  });

  final GuidanceLessonId id;
  final String title;
  final String body;
  final String route;
  final String actionLabel;
}

enum GuidanceMilestone {
  firstItem,
  firstSchedule,
  firstTimelineReview,
  firstCompletion,
  firstTaskDeferral,
  firstNexusReview,
  firstPlannerQuestion,
  firstSiQuery,
  firstTrajectoryReview,
  firstProgressionReview,
  guidanceDismissed,
  replayed,
}

final adaptiveGuidanceProvider =
    AsyncNotifierProvider<AdaptiveGuidanceNotifier, AdaptiveGuidanceState>(
      AdaptiveGuidanceNotifier.new,
    );

@immutable
class AdaptiveGuidanceState {
  const AdaptiveGuidanceState({
    required this.milestones,
    required this.counts,
    required this.skippedLessons,
    required this.completedLessons,
  });

  final Map<GuidanceMilestone, DateTime> milestones;
  final Map<GuidanceMilestone, int> counts;
  final Set<GuidanceLessonId> skippedLessons;
  final Set<GuidanceLessonId> completedLessons;

  bool has(GuidanceMilestone milestone) => milestones.containsKey(milestone);
  int count(GuidanceMilestone milestone) => counts[milestone] ?? 0;

  bool get coreComplete =>
      has(GuidanceMilestone.firstItem) &&
      has(GuidanceMilestone.firstSchedule) &&
      has(GuidanceMilestone.firstTimelineReview);

  bool get hasDeferralFriction =>
      count(GuidanceMilestone.firstTaskDeferral) >= 2;

  GuidanceLesson? nextIntervention({
    required String currentRoute,
    required DailyDecisionIntelligence decision,
  }) {
    return GuidanceInterventionEngine.resolve(
      state: this,
      currentRoute: currentRoute,
      decision: decision,
    );
  }
}

/// Chooses one intervention from observed state. There is no ordered lesson
/// catalog and no progress-card completion path.
abstract final class GuidanceInterventionEngine {
  static GuidanceLesson? resolve({
    required AdaptiveGuidanceState state,
    required String currentRoute,
    required DailyDecisionIntelligence decision,
  }) {
    GuidanceLesson? unresolved(GuidanceLesson lesson) {
      if (state.skippedLessons.contains(lesson.id) ||
          state.completedLessons.contains(lesson.id)) {
        return null;
      }
      return lesson;
    }

    if (!state.has(GuidanceMilestone.firstItem)) {
      return unresolved(
        const GuidanceLesson(
          id: GuidanceLessonId.createFirstItem,
          title: 'Capture the first real commitment',
          body:
              'Create one task with a concrete outcome. Guidance advances only after the item is saved.',
          route: RoutePaths.creator,
          actionLabel: 'Open Creator',
        ),
      );
    }
    if (!state.has(GuidanceMilestone.firstSchedule)) {
      return unresolved(
        const GuidanceLesson(
          id: GuidanceLessonId.scheduleFirstItem,
          title: 'Give the commitment a real time',
          body:
              'Add a date and time. This connects Creator, Smart Planner, and Timeline with evidence the app can use.',
          route: RoutePaths.creator,
          actionLabel: 'Schedule in Creator',
        ),
      );
    }
    if (!state.has(GuidanceMilestone.firstTimelineReview)) {
      return unresolved(
        const GuidanceLesson(
          id: GuidanceLessonId.reviewTimeline,
          title: 'Verify where the work landed',
          body:
              'Inspect the saved result on Timeline. Visiting the screen is recorded; tapping this prompt is not completion.',
          route: RoutePaths.timeline,
          actionLabel: 'Open Timeline',
        ),
      );
    }

    if (state.hasDeferralFriction) {
      final GuidanceLesson? recovery = unresolved(
        const GuidanceLesson(
          id: GuidanceLessonId.timelineExecution,
          title: 'Correct repeated deferral',
          body:
              'The plan has been deferred more than once. Reduce scope or move the item, then save the real outcome.',
          route: RoutePaths.timeline,
          actionLabel: 'Correct on Timeline',
        ),
      );
      if (recovery != null) return recovery;
    }

    final GuidanceLessonId? routeLesson = switch (currentRoute) {
      RoutePaths.nexus => GuidanceLessonId.nexus,
      RoutePaths.smartPlanner => GuidanceLessonId.smartPlanner,
      RoutePaths.timeline => GuidanceLessonId.timelineExecution,
      RoutePaths.siConsole => GuidanceLessonId.siConsole,
      RoutePaths.trajectoryEngine => GuidanceLessonId.trajectoryEngine,
      RoutePaths.progression => GuidanceLessonId.progression,
      _ => null,
    };
    if (routeLesson != null) {
      final GuidanceLesson? contextual = unresolved(
        _advancedLesson(routeLesson, decision),
      );
      if (contextual != null) return contextual;
    }

    if (decision.replanAction != null) {
      return unresolved(
        _advancedLesson(GuidanceLessonId.smartPlanner, decision),
      );
    }
    if (decision.confidence < .5) {
      return unresolved(_advancedLesson(GuidanceLessonId.siConsole, decision));
    }
    if (decision.observedOutcomes == 0) {
      return unresolved(
        _advancedLesson(GuidanceLessonId.timelineExecution, decision),
      );
    }
    if (!state.completedLessons.contains(GuidanceLessonId.nexus)) {
      return unresolved(_advancedLesson(GuidanceLessonId.nexus, decision));
    }
    if (!decision.warning.startsWith('No material constraint')) {
      return unresolved(
        _advancedLesson(GuidanceLessonId.trajectoryEngine, decision),
      );
    }
    return null;
  }

  static GuidanceLesson _advancedLesson(
    GuidanceLessonId id,
    DailyDecisionIntelligence decision,
  ) {
    return switch (id) {
      GuidanceLessonId.nexus => GuidanceLesson(
        id: id,
        title: 'Inspect why this block is next',
        body:
            '${decision.rationale} Review the inline rationale and stated uncertainty before acting.',
        route: RoutePaths.nexus,
        actionLabel: 'Inspect in Nexus',
      ),
      GuidanceLessonId.smartPlanner => GuidanceLesson(
        id: id,
        title: 'Interrogate the active plan',
        body:
            '${decision.replanAction ?? 'Ask one specific question about the ranked task, its constraints, or what should move.'} Guidance waits for a submitted question.',
        route: RoutePaths.smartPlanner,
        actionLabel: 'Ask Smart Planner',
      ),
      GuidanceLessonId.timelineExecution => GuidanceLesson(
        id: id,
        title: 'Create an outcome the system can learn from',
        body:
            'Complete, defer, or correct one scheduled item. Only the saved outcome advances this intervention.',
        route: RoutePaths.timeline,
        actionLabel: 'Open executable work',
      ),
      GuidanceLessonId.siConsole => GuidanceLesson(
        id: id,
        title: 'Challenge weak or incomplete evidence',
        body:
            '${decision.warning} Ask what evidence is missing and what input could change the recommendation.',
        route: RoutePaths.siConsole,
        actionLabel: 'Inspect evidence',
      ),
      GuidanceLessonId.trajectoryEngine => GuidanceLesson(
        id: id,
        title: 'Compare a real alternative',
        body:
            'Model one change to time, scope, or priority. Compare the consequence and assumptions instead of treating the path as certain.',
        route: RoutePaths.trajectoryEngine,
        actionLabel: 'Compare paths',
      ),
      GuidanceLessonId.progression => const GuidanceLesson(
        id: GuidanceLessonId.progression,
        title: 'Verify what became reliable',
        body:
            'Review the outcomes behind progression. The actual review event completes this intervention.',
        route: RoutePaths.progression,
        actionLabel: 'Review outcomes',
      ),
      GuidanceLessonId.createFirstItem ||
      GuidanceLessonId.scheduleFirstItem ||
      GuidanceLessonId.reviewTimeline => throw ArgumentError(
        'Core-loop lessons are resolved separately.',
      ),
    };
  }
}

class AdaptiveGuidanceNotifier extends AsyncNotifier<AdaptiveGuidanceState> {
  static const String _storageKey = 'adaptive_guidance_v3';

  String _prefix(String scope) => '$_storageKey.$scope';

  String? get _activeScope {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    return scope.isWritable ? scope.v2Namespace : null;
  }

  @override
  Future<AdaptiveGuidanceState> build() async {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    final String? account = scope.isWritable ? scope.v2Namespace : null;
    if (account == null) return _emptyState;
    final String prefix = _prefix(account);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<GuidanceMilestone, DateTime> milestones =
        <GuidanceMilestone, DateTime>{};
    final Map<GuidanceMilestone, int> counts = <GuidanceMilestone, int>{};

    for (final GuidanceMilestone milestone in GuidanceMilestone.values) {
      final int? timestamp = prefs.getInt('$prefix.${milestone.name}.at');
      if (timestamp != null) {
        milestones[milestone] = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      counts[milestone] = prefs.getInt('$prefix.${milestone.name}.count') ?? 0;
    }

    final Set<GuidanceLessonId> skipped = GuidanceLessonId.values
        .where(
          (GuidanceLessonId id) =>
              prefs.getBool('$prefix.skip.${id.name}') ?? false,
        )
        .toSet();
    final Set<GuidanceLessonId> completed =
        GuidanceLessonId.values
            .where(
              (GuidanceLessonId id) =>
                  prefs.getBool('$prefix.complete.${id.name}') ?? false,
            )
            .toSet()
          ..addAll(_lessonsCompletedBy(milestones.keys));

    return AdaptiveGuidanceState(
      milestones: milestones,
      counts: counts,
      skippedLessons: skipped,
      completedLessons: completed,
    );
  }

  Future<void> record(GuidanceMilestone milestone) async {
    final String? account = _activeScope;
    if (account == null) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account) return;
    final String prefix = _prefix(account);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int nextCount = current.count(milestone) + 1;
    final DateTime timestamp = current.milestones[milestone] ?? DateTime.now();
    final GuidanceLessonId? completedLesson = _lessonCompletedBy(milestone);

    await prefs.setInt(
      '$prefix.${milestone.name}.at',
      timestamp.millisecondsSinceEpoch,
    );
    await prefs.setInt('$prefix.${milestone.name}.count', nextCount);
    if (completedLesson != null) {
      await prefs.setBool('$prefix.complete.${completedLesson.name}', true);
    }

    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{
          ...current.milestones,
          milestone: timestamp,
        },
        counts: <GuidanceMilestone, int>{
          ...current.counts,
          milestone: nextCount,
        },
        skippedLessons: current.skippedLessons,
        completedLessons: <GuidanceLessonId>{
          ...current.completedLessons,
          ?completedLesson,
        },
      ),
    );
  }

  Future<void> skip(GuidanceLessonId lesson) async {
    final String? account = _activeScope;
    if (account == null) return;
    await record(GuidanceMilestone.guidanceDismissed);
    if (_activeScope != account) return;
    final AdaptiveGuidanceState current = await _current();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix(account)}.skip.${lesson.name}', true);
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: <GuidanceLessonId>{...current.skippedLessons, lesson},
        completedLessons: current.completedLessons,
      ),
    );
  }

  Future<void> restartLessons() async {
    final String? account = _activeScope;
    if (account == null) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account) return;
    final String prefix = _prefix(account);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final GuidanceLessonId id in GuidanceLessonId.values) {
      await prefs.remove('$prefix.skip.${id.name}');
      await prefs.remove('$prefix.complete.${id.name}');
    }
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: const <GuidanceLessonId>{},
        completedLessons: _lessonsCompletedBy(current.milestones.keys),
      ),
    );
  }

  Future<void> replayOnboarding() async {
    if (_activeScope == null) return;
    await record(GuidanceMilestone.replayed);
    await restartLessons();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompleteStorageKey, false);
    await prefs.setInt(onboardingContentVersionStorageKey, 0);
    ref.read(onboardingCompleteProvider.notifier).set(false);
  }

  Future<AdaptiveGuidanceState> _current() async {
    return state.asData?.value ?? future;
  }

  static const AdaptiveGuidanceState _emptyState = AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{},
    counts: <GuidanceMilestone, int>{},
    skippedLessons: <GuidanceLessonId>{},
    completedLessons: <GuidanceLessonId>{},
  );
}

Set<GuidanceLessonId> _lessonsCompletedBy(
  Iterable<GuidanceMilestone> milestones,
) {
  return milestones
      .map(_lessonCompletedBy)
      .whereType<GuidanceLessonId>()
      .toSet();
}

GuidanceLessonId? _lessonCompletedBy(GuidanceMilestone milestone) {
  return switch (milestone) {
    GuidanceMilestone.firstItem => GuidanceLessonId.createFirstItem,
    GuidanceMilestone.firstSchedule => GuidanceLessonId.scheduleFirstItem,
    GuidanceMilestone.firstTimelineReview => GuidanceLessonId.reviewTimeline,
    GuidanceMilestone.firstCompletion ||
    GuidanceMilestone.firstTaskDeferral => GuidanceLessonId.timelineExecution,
    GuidanceMilestone.firstNexusReview => GuidanceLessonId.nexus,
    GuidanceMilestone.firstPlannerQuestion => GuidanceLessonId.smartPlanner,
    GuidanceMilestone.firstSiQuery => GuidanceLessonId.siConsole,
    GuidanceMilestone.firstTrajectoryReview =>
      GuidanceLessonId.trajectoryEngine,
    GuidanceMilestone.firstProgressionReview => GuidanceLessonId.progression,
    GuidanceMilestone.guidanceDismissed || GuidanceMilestone.replayed => null,
  };
}
