import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
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
    this.laterLessons = const <GuidanceLessonId>{},
    this.replayLessons = const <GuidanceLessonId>{},
    this.expectedFirstRunCreatorTaskIds = const <String>{},
  });

  final Map<GuidanceMilestone, DateTime> milestones;
  final Map<GuidanceMilestone, int> counts;
  final Set<GuidanceLessonId> skippedLessons;
  final Set<GuidanceLessonId> completedLessons;
  final Set<GuidanceLessonId> laterLessons;
  final Set<GuidanceLessonId> replayLessons;
  final Set<String> expectedFirstRunCreatorTaskIds;

  bool has(GuidanceMilestone milestone) => milestones.containsKey(milestone);
  int count(GuidanceMilestone milestone) => counts[milestone] ?? 0;

  bool matchesExpectedFirstRunCreatorTask(String taskId) {
    return expectedFirstRunCreatorTaskIds.contains(taskId.trim());
  }

  bool get coreComplete =>
      has(GuidanceMilestone.firstItem) &&
      has(GuidanceMilestone.firstSchedule) &&
      has(GuidanceMilestone.firstTimelineReview);

  static const Duration postCoreQuietPeriod = Duration(hours: 24);

  bool isInPostCoreQuietPeriod(DateTime now) {
    final DateTime? completedAt =
        milestones[GuidanceMilestone.firstTimelineReview];
    if (!coreComplete || completedAt == null) return false;
    final Duration elapsed = now.toUtc().difference(completedAt.toUtc());
    // A device-clock rollback must not make a just-completed tutorial reappear.
    return elapsed.isNegative || elapsed < postCoreQuietPeriod;
  }

  bool get hasDeferralFriction =>
      count(GuidanceMilestone.firstTaskDeferral) >= 2;

  /// Whether first-run (or replayed) core guidance decides the next lesson.
  bool get coreGuidanceOwnsState =>
      replayLessons.any(_replayableCoreLessons.contains) || !coreComplete;

  /// The core lesson currently shown, or null when core guidance is complete,
  /// paused, or muted. Creator and the overlay must agree on this value.
  GuidanceLessonId? get activeCoreLesson =>
      GuidanceInterventionEngine.activeCoreLesson(this);

  /// Creator runs its guided first-task form exactly when a core Creator lesson
  /// is active, so every spotlight target the overlay expects is mounted.
  bool get guidesCreatorTask => switch (activeCoreLesson) {
    GuidanceLessonId.createFirstItem ||
    GuidanceLessonId.scheduleFirstItem => true,
    _ => false,
  };

  /// A Creator receipt is only useful while the Timeline review step is
  /// still ahead.
  bool get awaitsTimelineReview =>
      !has(GuidanceMilestone.firstTimelineReview) ||
      replayLessons.contains(GuidanceLessonId.reviewTimeline);

  GuidanceLesson? nextIntervention({
    required String currentRoute,
    required DailyDecisionIntelligence decision,
    DateTime? now,
  }) {
    return GuidanceInterventionEngine.resolve(
      state: this,
      currentRoute: currentRoute,
      decision: decision,
      now: now ?? DateTime.now(),
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
    required DateTime now,
  }) {
    GuidanceLesson? unresolved(GuidanceLesson lesson) {
      if (state.skippedLessons.contains(lesson.id) ||
          state.laterLessons.contains(lesson.id) ||
          state.completedLessons.contains(lesson.id)) {
        return null;
      }
      return lesson;
    }

    if (state.coreGuidanceOwnsState) {
      final GuidanceLessonId? core = activeCoreLesson(state);
      return core == null ? null : _coreLesson(core);
    }

    if (state.hasDeferralFriction) {
      final GuidanceLesson? recovery = unresolved(
        const GuidanceLesson(
          id: GuidanceLessonId.timelineExecution,
          title: 'Try a smaller step or a different time',
          body:
              'You moved this more than once. You can make it smaller, choose another time, or record what happened.',
          route: RoutePaths.timeline,
          actionLabel: 'Review in schedule',
        ),
      );
      if (recovery != null) return recovery;
    }

    // Finishing first-run setup should hand control back to the product. Do not
    // replace Nexus with another modal lesson immediately; advanced guidance
    // can resume after the user has had an uninterrupted day with the app.
    if (state.isInPostCoreQuietPeriod(now)) return null;

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

  static GuidanceLessonId? activeCoreLesson(AdaptiveGuidanceState state) {
    bool muted(GuidanceLessonId id) =>
        state.laterLessons.contains(id) || state.skippedLessons.contains(id);

    GuidanceLessonId? withReceipt(GuidanceLessonId id) {
      if (id == GuidanceLessonId.reviewTimeline &&
          state.expectedFirstRunCreatorTaskIds.isEmpty) {
        // The Timeline spotlight requires an exact Creator receipt. Older
        // accounts can have both task milestones without that receipt.
        return muted(GuidanceLessonId.createFirstItem)
            ? null
            : GuidanceLessonId.createFirstItem;
      }
      return id;
    }

    for (final GuidanceLessonId id in _replayableCoreLessons) {
      if (!state.replayLessons.contains(id)) continue;
      return muted(id) ? null : withReceipt(id);
    }

    if (state.coreComplete) return null;
    for (final (GuidanceMilestone milestone, GuidanceLessonId lesson)
        in <(GuidanceMilestone, GuidanceLessonId)>[
          (GuidanceMilestone.firstItem, GuidanceLessonId.createFirstItem),
          (GuidanceMilestone.firstSchedule, GuidanceLessonId.scheduleFirstItem),
          (
            GuidanceMilestone.firstTimelineReview,
            GuidanceLessonId.reviewTimeline,
          ),
        ]) {
      if (state.has(milestone)) continue;
      // A deferred or muted lesson must not be replaced by a later step.
      return muted(lesson) ? null : withReceipt(lesson);
    }
    return null;
  }

  static GuidanceLesson _coreLesson(GuidanceLessonId id) {
    return switch (id) {
      GuidanceLessonId.createFirstItem => const GuidanceLesson(
        id: GuidanceLessonId.createFirstItem,
        title: 'Add your first task',
        body:
            'Write one thing you need to do. Review it and confirm to save it. Next, you can choose a time for it.',
        route: RoutePaths.creator,
        actionLabel: 'Add a task',
      ),
      GuidanceLessonId.scheduleFirstItem => const GuidanceLesson(
        id: GuidanceLessonId.scheduleFirstItem,
        title: 'Choose when to do it',
        body:
            'Give your task a date and time so it appears in your plan. You can change the time later.',
        route: RoutePaths.creator,
        actionLabel: 'Choose a date and time',
      ),
      GuidanceLessonId.reviewTimeline => const GuidanceLesson(
        id: GuidanceLessonId.reviewTimeline,
        title: 'Find your saved task',
        body:
            'Open the task you just saved in your schedule. Check its date and details.',
        route: RoutePaths.timeline,
        actionLabel: 'Open schedule',
      ),
      GuidanceLessonId.nexus ||
      GuidanceLessonId.smartPlanner ||
      GuidanceLessonId.timelineExecution ||
      GuidanceLessonId.siConsole ||
      GuidanceLessonId.trajectoryEngine ||
      GuidanceLessonId.progression => throw ArgumentError(
        'Only core lessons can be replayed as first-run guidance.',
      ),
    };
  }

  static GuidanceLesson _advancedLesson(
    GuidanceLessonId id,
    DailyDecisionIntelligence decision,
  ) {
    return switch (id) {
      GuidanceLessonId.nexus => GuidanceLesson(
        id: id,
        title: 'Review the suggested next step',
        body:
            '${decision.rationale} Read why it was suggested and what is uncertain before deciding.',
        route: RoutePaths.nexus,
        actionLabel: 'Review today',
      ),
      GuidanceLessonId.smartPlanner => GuidanceLesson(
        id: id,
        title: 'Ask for help with a plan',
        body:
            '${decision.replanAction ?? 'Ask one specific question about the ranked task, its constraints, or what should move.'} Type a question to get a suggestion.',
        route: RoutePaths.smartPlanner,
        actionLabel: 'Ask for a next step',
      ),
      GuidanceLessonId.timelineExecution => GuidanceLesson(
        id: id,
        title: 'Record what happened',
        body:
            'Open a scheduled task. Mark it done, move it, or correct its details, then save your change.',
        route: RoutePaths.timeline,
        actionLabel: 'Open schedule',
      ),
      GuidanceLessonId.siConsole => GuidanceLesson(
        id: id,
        title: 'Ask what is missing',
        body:
            '${decision.warning} Ask what evidence is missing and what input could change the recommendation. '
            'Free tools use no credits; questions to cloud AI show their price, up to 5 credits, before you confirm. Eligible free plans include 20 credits per month without rollover; check Settings for your allowance and reset date.',
        route: RoutePaths.siConsole,
        actionLabel: 'Inspect evidence',
      ),
      GuidanceLessonId.trajectoryEngine => GuidanceLesson(
        id: id,
        title: 'Compare another option',
        body:
            'Try a different time, amount of work, or priority. Compare the estimate before changing your plan.',
        route: RoutePaths.trajectoryEngine,
        actionLabel: 'Compare options',
      ),
      GuidanceLessonId.progression => const GuidanceLesson(
        id: GuidanceLessonId.progression,
        title: 'Review your activity',
        body:
            'See the tasks and milestones you recorded. Open the details to review them.',
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
  static const String _expectedCreatorTaskIdsKey =
      'expected_first_run_creator_task_ids';

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
    await _reconcileTaskMilestones(
      account: account,
      prefix: prefix,
      prefs: prefs,
      milestones: milestones,
      counts: counts,
    );

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
    final Set<GuidanceLessonId> later = GuidanceLessonId.values
        .where(
          (GuidanceLessonId id) =>
              prefs.getBool('$prefix.later.${id.name}') ?? false,
        )
        .toSet();
    final Set<GuidanceLessonId> replay = GuidanceLessonId.values
        .where(
          (GuidanceLessonId id) =>
              prefs.getBool('$prefix.replay.${id.name}') ?? false,
        )
        .toSet();
    final Set<String> expectedCreatorTaskIds =
        (prefs.getStringList('$prefix.$_expectedCreatorTaskIdsKey') ??
                const <String>[])
            .map((String id) => id.trim())
            .where((String id) => id.isNotEmpty)
            .toSet();

    return AdaptiveGuidanceState(
      milestones: milestones,
      counts: counts,
      skippedLessons: skipped,
      completedLessons: completed,
      laterLessons: later,
      replayLessons: replay,
      expectedFirstRunCreatorTaskIds: expectedCreatorTaskIds,
    );
  }

  Future<void> record(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async {
    final String? account = _activeScope;
    if (account == null || shouldContinue?.call() == false) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account || shouldContinue?.call() == false) return;
    final String prefix = _prefix(account);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account || shouldContinue?.call() == false) return;
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
      await prefs.remove('$prefix.later.${completedLesson.name}');
      await prefs.remove('$prefix.replay.${completedLesson.name}');
    }
    if (milestone == GuidanceMilestone.firstTimelineReview) {
      await prefs.remove('$prefix.$_expectedCreatorTaskIdsKey');
    }

    if (!ref.mounted ||
        _activeScope != account ||
        shouldContinue?.call() == false) {
      return;
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
        laterLessons: <GuidanceLessonId>{...current.laterLessons}
          ..remove(completedLesson),
        replayLessons: <GuidanceLessonId>{...current.replayLessons}
          ..remove(completedLesson),
        expectedFirstRunCreatorTaskIds:
            milestone == GuidanceMilestone.firstTimelineReview
            ? const <String>{}
            : current.expectedFirstRunCreatorTaskIds,
      ),
    );
  }

  Future<void> recordIfMissing(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async {
    final account = _activeScope;
    if (account == null || shouldContinue?.call() == false) return;
    final AdaptiveGuidanceState current = await _current();
    final GuidanceLessonId? lesson = _lessonCompletedBy(milestone);
    if (!ref.mounted ||
        _activeScope != account ||
        shouldContinue?.call() == false ||
        (current.has(milestone) && !current.replayLessons.contains(lesson))) {
      return;
    }
    await record(milestone, shouldContinue: shouldContinue);
  }

  Future<void> recordCreatorHandshakeReceipt(
    CreatorHandshakeReceipt receipt,
  ) async {
    final String? account = _activeScope;
    if (account == null || receipt.accountScopeId != account) return;
    final Set<String> taskIds = receipt.taskIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (taskIds.isEmpty || receipt.appliedOperationIds.isEmpty) return;

    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account || !current.awaitsTimelineReview) return;
    final Set<String> expectedTaskIds = <String>{
      ...current.expectedFirstRunCreatorTaskIds,
      ...taskIds,
    };
    final List<String> persistedTaskIds = expectedTaskIds.toList()..sort();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '${_prefix(account)}.$_expectedCreatorTaskIdsKey',
      persistedTaskIds,
    );
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: current.completedLessons,
        laterLessons: current.laterLessons,
        replayLessons: current.replayLessons,
        expectedFirstRunCreatorTaskIds: expectedTaskIds,
      ),
    );
  }

  Future<void> later(GuidanceLessonId lesson) async {
    final String? account = _activeScope;
    if (account == null) return;
    await record(GuidanceMilestone.guidanceDismissed);
    if (_activeScope != account) return;
    final AdaptiveGuidanceState current = await _current();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<GuidanceLessonId> pausedLessons =
        _replayableCoreLessons.contains(lesson)
        ? _replayableCoreLessons
        : <GuidanceLessonId>{lesson};
    for (final id in pausedLessons) {
      await prefs.setBool('${_prefix(account)}.later.${id.name}', true);
    }
    // "Finish later" pauses the whole core replay, rather than jumping to the
    // next replay step or reopening the current step on the following frame.
    final Set<GuidanceLessonId> replay = current.replayLessons.contains(lesson)
        ? const <GuidanceLessonId>{}
        : current.replayLessons;
    if (replay.isEmpty) {
      for (final GuidanceLessonId id in current.replayLessons) {
        await prefs.remove('${_prefix(account)}.replay.${id.name}');
      }
    }
    if (_activeScope != account) return;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: current.completedLessons,
        laterLessons: <GuidanceLessonId>{
          ...current.laterLessons,
          ...pausedLessons,
        },
        replayLessons: replay,
        expectedFirstRunCreatorTaskIds: current.expectedFirstRunCreatorTaskIds,
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
    await prefs.remove('${_prefix(account)}.later.${lesson.name}');
    await prefs.remove('${_prefix(account)}.replay.${lesson.name}');
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: <GuidanceLessonId>{...current.skippedLessons, lesson},
        completedLessons: current.completedLessons,
        laterLessons: <GuidanceLessonId>{...current.laterLessons}
          ..remove(lesson),
        replayLessons: <GuidanceLessonId>{...current.replayLessons}
          ..remove(lesson),
        expectedFirstRunCreatorTaskIds: current.expectedFirstRunCreatorTaskIds,
      ),
    );
  }

  Future<void> restartLessons() => _restartLessons(replayCore: true);

  Future<void> _restartLessons({required bool replayCore}) async {
    final String? account = _activeScope;
    if (account == null) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account) return;
    final String prefix = _prefix(account);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final GuidanceLessonId id in GuidanceLessonId.values) {
      await prefs.remove('$prefix.complete.${id.name}');
      await prefs.remove('$prefix.later.${id.name}');
      if (replayCore && _replayableCoreLessons.contains(id)) {
        // An explicit restart is a new choice to revisit core guidance.
        await prefs.remove('$prefix.skip.${id.name}');
        await prefs.setBool('$prefix.replay.${id.name}', true);
      } else {
        await prefs.remove('$prefix.replay.${id.name}');
      }
    }
    await prefs.remove('$prefix.$_expectedCreatorTaskIdsKey');
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: replayCore
            ? current.skippedLessons.difference(_replayableCoreLessons)
            : current.skippedLessons,
        completedLessons: _lessonsCompletedBy(current.milestones.keys),
        laterLessons: const <GuidanceLessonId>{},
        replayLessons: replayCore
            ? _replayableCoreLessons
            : const <GuidanceLessonId>{},
        expectedFirstRunCreatorTaskIds: const <String>{},
      ),
    );
  }

  Future<void> replayOnboarding() async {
    if (_activeScope == null) return;
    await record(GuidanceMilestone.replayed);
    await _restartLessons(replayCore: true);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingWelcomeCompleteStorageKey, false);
    await prefs.setBool(onboardingCompleteStorageKey, false);
    await prefs.setInt(onboardingContentVersionStorageKey, 0);
    await ref.read(accountOnboardingCompleteProvider.notifier).reset();
    ref.read(onboardingCompleteProvider.notifier).set(false);
    ref.read(onboardingWelcomeCompleteProvider.notifier).set(false);
  }

  Future<AdaptiveGuidanceState> _current() async {
    return state.asData?.value ?? future;
  }

  Future<void> _reconcileTaskMilestones({
    required String account,
    required String prefix,
    required SharedPreferences prefs,
    required Map<GuidanceMilestone, DateTime> milestones,
    required Map<GuidanceMilestone, int> counts,
  }) async {
    final List<TaskEntity> tasks;
    try {
      tasks = await ref.read(domainTaskRepositoryProvider).getAllTasks();
    } on Object {
      return;
    }
    if (_activeScope != account || tasks.isEmpty) return;

    Future<void> infer(GuidanceMilestone milestone) async {
      if (milestones.containsKey(milestone)) return;
      final DateTime observedAt = DateTime.now();
      milestones[milestone] = observedAt;
      counts[milestone] = counts[milestone] == 0 ? 1 : counts[milestone]!;
      await prefs.setInt(
        '$prefix.${milestone.name}.at',
        observedAt.millisecondsSinceEpoch,
      );
      await prefs.setInt('$prefix.${milestone.name}.count', counts[milestone]!);
      final GuidanceLessonId? completedLesson = _lessonCompletedBy(milestone);
      if (completedLesson != null) {
        await prefs.setBool('$prefix.complete.${completedLesson.name}', true);
      }
    }

    await infer(GuidanceMilestone.firstItem);
    if (tasks.any(
      (TaskEntity task) => task.scheduledFor != null || task.dueDate != null,
    )) {
      await infer(GuidanceMilestone.firstSchedule);
    }
  }

  static const AdaptiveGuidanceState _emptyState = AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{},
    counts: <GuidanceMilestone, int>{},
    skippedLessons: <GuidanceLessonId>{},
    completedLessons: <GuidanceLessonId>{},
    laterLessons: <GuidanceLessonId>{},
    replayLessons: <GuidanceLessonId>{},
    expectedFirstRunCreatorTaskIds: <String>{},
  );
}

const Set<GuidanceLessonId> _replayableCoreLessons = <GuidanceLessonId>{
  GuidanceLessonId.createFirstItem,
  GuidanceLessonId.scheduleFirstItem,
  GuidanceLessonId.reviewTimeline,
};

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
