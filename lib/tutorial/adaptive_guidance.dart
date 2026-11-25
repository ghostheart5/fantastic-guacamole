import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart'
    show GuidanceLessonId, GuidanceMilestone;

@immutable
class GuidanceLesson {
  const GuidanceLesson({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.actionLabel,
    this.hint,
  });

  final GuidanceLessonId id;
  final String title;
  final String body;
  final String route;

  /// Empty for a hint without an action.
  final String actionLabel;

  /// The catalogue entry of a contextual hint; null for a first-run step.
  final GuidanceHint? hint;
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
    this.untilReopenedLessons = const <GuidanceLessonId>{},
    this.skippedCoreSteps = const <GuidanceLessonId>{},
  });

  final Map<GuidanceMilestone, DateTime> milestones;
  final Map<GuidanceMilestone, int> counts;
  final Set<GuidanceLessonId> skippedLessons;
  final Set<GuidanceLessonId> completedLessons;
  final Set<GuidanceLessonId> laterLessons;
  final Set<GuidanceLessonId> replayLessons;
  final Set<String> expectedFirstRunCreatorTaskIds;

  /// Core lessons hidden until the app is next opened. Never stored, so the guide
  /// returns on the next launch.
  final Set<GuidanceLessonId> untilReopenedLessons;

  /// First-run guide steps passed over with "Skip this step". Unlike a skip
  /// of the whole guide (stored in [skippedLessons], which older versions
  /// also wrote for a single step), the guide moves on to its next step.
  final Set<GuidanceLessonId> skippedCoreSteps;

  bool has(GuidanceMilestone milestone) => milestones.containsKey(milestone);
  int count(GuidanceMilestone milestone) => counts[milestone] ?? 0;

  /// Whether a real action recorded for this account, not just reading or
  /// dismissing a hint, has finished [lesson].
  bool lessonFinishedByAction(GuidanceLessonId lesson) => milestones.keys.any(
    (GuidanceMilestone milestone) => _lessonCompletedBy(milestone) == lesson,
  );

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

  /// Whether the person explicitly skipped the first-run guide. A pause (the
  /// stored `later` flags, which older versions also wrote for a skipped setup)
  /// is reported separately by [coreGuideStatus].
  bool get coreGuideSkipped =>
      skippedLessons.any(_replayableCoreLessons.contains);

  /// Plain description of the first-run guide for status displays.
  CoreGuideStatus get coreGuideStatus {
    if (!coreGuidanceOwnsState) return CoreGuideStatus.complete;
    if (activeCoreLesson != null) return CoreGuideStatus.active;
    if (coreGuideSkipped) return CoreGuideStatus.skipped;
    final bool paused = _replayableCoreLessons.any(
      (GuidanceLessonId id) =>
          laterLessons.contains(id) || untilReopenedLessons.contains(id),
    );
    // Without a pause, a guide that stopped after "Skip this step" ended
    // because its remaining steps were skipped.
    return !paused && skippedCoreSteps.any(_replayableCoreLessons.contains)
        ? CoreGuideStatus.skipped
        : CoreGuideStatus.paused;
  }

  /// The first-run guide as the person sees it: step 1 adds and schedules a
  /// task in Add something (one form, two lessons), step 2 finds it on the
  /// schedule.
  static const int coreStepCount = 2;

  /// The 1-based step [lesson] belongs to, or null for a contextual lesson.
  static int? coreStepNumber(GuidanceLessonId lesson) => switch (lesson) {
    GuidanceLessonId.createFirstItem || GuidanceLessonId.scheduleFirstItem => 1,
    GuidanceLessonId.reviewTimeline => 2,
    _ => null,
  };

  static Set<GuidanceLessonId> _coreStepLessons(GuidanceLessonId lesson) =>
      switch (coreStepNumber(lesson)) {
        1 => const <GuidanceLessonId>{
          GuidanceLessonId.createFirstItem,
          GuidanceLessonId.scheduleFirstItem,
        },
        2 => const <GuidanceLessonId>{GuidanceLessonId.reviewTimeline},
        _ => const <GuidanceLessonId>{},
      };

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

  /// [currentRoute] is the router location, or the [GuidancePlaces] key a
  /// screen or area in view declares. [reminderSavedWhileNotificationsOff]
  /// is true on the screen where something with a reminder was just saved
  /// while notifications are off and the request was already refused.
  GuidanceLesson? nextIntervention({
    required String currentRoute,
    required DailyDecisionIntelligence decision,
    DateTime? now,
    bool reminderSavedWhileNotificationsOff = false,
  }) {
    return GuidanceInterventionEngine.resolve(
      state: this,
      currentRoute: currentRoute,
      decision: decision,
      now: now ?? DateTime.now(),
      reminderSavedWhileNotificationsOff: reminderSavedWhileNotificationsOff,
    );
  }
}

enum CoreGuideStatus { active, paused, skipped, complete }

/// Chooses one intervention from observed state. Contextual hints come from
/// [GuidanceCatalogue]; there is no progress-card completion path.
abstract final class GuidanceInterventionEngine {
  static GuidanceLesson? resolve({
    required AdaptiveGuidanceState state,
    required String currentRoute,
    required DailyDecisionIntelligence decision,
    required DateTime now,
    bool reminderSavedWhileNotificationsOff = false,
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
      if (core != null) return _coreLesson(core);
      // A skipped or paused first-run guide stays off until it is restarted
      // in Settings, but the small, non-blocking hint for the screen in view
      // still appears.
    }

    // About something just saved on this screen, so it comes first, even
    // right after the first-run guide.
    if (reminderSavedWhileNotificationsOff) {
      final GuidanceLesson? off = unresolved(
        _hintLesson(GuidanceCatalogue.remindersOff, decision, currentRoute),
      );
      if (off != null) return off;
    }

    // A contextual lesson describes one screen, so it appears only there.
    // Screens without a lesson of their own (Settings outside its
    // Notifications area, Add something...) never show guidance about
    // another screen.
    final GuidanceHint? hint = GuidanceCatalogue.forPlace(currentRoute);
    if (hint == null || hint.id == GuidanceLessonId.remindersOff) return null;

    if (hint.id == GuidanceLessonId.timelineExecution &&
        state.hasDeferralFriction) {
      final GuidanceLesson? recovery = unresolved(
        _hintLesson(GuidanceCatalogue.timelineRecovery, decision),
      );
      if (recovery != null) return recovery;
    }

    // Finishing first-run setup should hand control back to the product. Do not
    // replace Nexus with another modal lesson immediately; advanced guidance
    // can resume after the user has had an uninterrupted day with the app.
    if (state.isInPostCoreQuietPeriod(now)) return null;

    // A finished or dismissed lesson is not replaced by one about another
    // screen.
    return unresolved(_hintLesson(hint, decision));
  }

  static GuidanceLessonId? activeCoreLesson(AdaptiveGuidanceState state) {
    bool muted(GuidanceLessonId id) =>
        state.laterLessons.contains(id) ||
        state.skippedLessons.contains(id) ||
        state.untilReopenedLessons.contains(id);
    bool stepSkipped(GuidanceLessonId id) =>
        state.skippedCoreSteps.contains(id);

    GuidanceLessonId? withReceipt(GuidanceLessonId id) {
      if (id == GuidanceLessonId.reviewTimeline &&
          state.expectedFirstRunCreatorTaskIds.isEmpty) {
        // The Timeline step needs the exact task the guide saved. Older
        // accounts can have both task milestones without that receipt; after
        // "Skip this step" on the first step there is nothing to find.
        return muted(GuidanceLessonId.createFirstItem) ||
                stepSkipped(GuidanceLessonId.createFirstItem)
            ? null
            : GuidanceLessonId.createFirstItem;
      }
      return id;
    }

    for (final GuidanceLessonId id in _replayableCoreLessons) {
      if (!state.replayLessons.contains(id) || stepSkipped(id)) continue;
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
      // "Skip this step" moves on to the next step.
      if (state.has(milestone) || stepSkipped(lesson)) continue;
      // A paused or muted lesson must not be replaced by a later step.
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
      _ => throw ArgumentError(
        'Only core lessons can be replayed as first-run guidance.',
      ),
    };
  }

  /// A catalogue hint as a lesson. Some English bodies start with a line
  /// about today's plan; [route] places a hint that has no screen of its own.
  static GuidanceLesson _hintLesson(
    GuidanceHint hint,
    DailyDecisionIntelligence decision, [
    String? route,
  ]) {
    final String? lead = switch (hint.id) {
      GuidanceLessonId.nexus => decision.rationale,
      GuidanceLessonId.smartPlanner => decision.replanAction,
      GuidanceLessonId.siConsole => decision.warning,
      _ => null,
    };
    return GuidanceLesson(
      id: hint.id,
      title: hint.title.en,
      body: lead == null || lead.trim().isEmpty
          ? hint.body.en
          : '$lead ${hint.body.en}',
      route: route ?? hint.route,
      actionLabel: hint.action?.label.en ?? '',
      hint: hint,
    );
  }
}

class AdaptiveGuidanceNotifier extends AsyncNotifier<AdaptiveGuidanceState> {
  static const String _storageKey = 'adaptive_guidance_v3';
  static const String _expectedCreatorTaskIdsKey =
      'expected_first_run_creator_task_ids';
  static const String _skipStepKey = 'skipStep';

  /// How many saved task ids the schedule step keeps looking for.
  static const int maxExpectedCreatorTaskIds = 20;

  static List<String> _newestTaskIds(List<String> oldestFirst) =>
      oldestFirst.length <= maxExpectedCreatorTaskIds
      ? oldestFirst
      : oldestFirst.sublist(oldestFirst.length - maxExpectedCreatorTaskIds);

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
    final Set<GuidanceLessonId> skippedSteps = _replayableCoreLessons
        .where(
          (GuidanceLessonId id) =>
              prefs.getBool('$prefix.$_skipStepKey.${id.name}') ?? false,
        )
        .toSet();
    // Oldest first. Older versions stored a sorted list that could grow
    // without limit; it still loads, cut to the cap.
    final List<String> storedTaskIds =
        (prefs.getStringList('$prefix.$_expectedCreatorTaskIdsKey') ??
                const <String>[])
            .map((String id) => id.trim())
            .where((String id) => id.isNotEmpty)
            .toSet()
            .toList();

    return AdaptiveGuidanceState(
      milestones: milestones,
      counts: counts,
      skippedLessons: skipped,
      completedLessons: completed,
      laterLessons: later,
      replayLessons: replay,
      expectedFirstRunCreatorTaskIds: _newestTaskIds(storedTaskIds).toSet(),
      skippedCoreSteps: skippedSteps,
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
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
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
    // Only the first-run guide looks for these tasks: a skipped, paused or
    // finished guide keeps no list.
    if (_activeScope != account || current.activeCoreLesson == null) return;
    final List<String> persistedTaskIds = _newestTaskIds(<String>[
      ...current.expectedFirstRunCreatorTaskIds.where(
        (String id) => !taskIds.contains(id),
      ),
      ...taskIds,
    ]);
    final Set<String> expectedTaskIds = persistedTaskIds.toSet();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    await prefs.setStringList(
      '${_prefix(account)}.$_expectedCreatorTaskIdsKey',
      persistedTaskIds,
    );
    if (!ref.mounted || _activeScope != account) return;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: current.completedLessons,
        laterLessons: current.laterLessons,
        replayLessons: current.replayLessons,
        expectedFirstRunCreatorTaskIds: expectedTaskIds,
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
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
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
      ),
    );
  }

  /// "Continue here" on a contextual lesson: the person has read it and is
  /// using the screen, so it is finished for this account. First-run guide
  /// steps finish only through their real milestones.
  Future<void> completeLesson(GuidanceLessonId lesson) async {
    if (_replayableCoreLessons.contains(lesson)) return;
    final String? account = _activeScope;
    if (account == null) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    final String prefix = _prefix(account);
    await prefs.setBool('$prefix.complete.${lesson.name}', true);
    await prefs.remove('$prefix.later.${lesson.name}');
    if (!ref.mounted || _activeScope != account) return;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: <GuidanceLessonId>{
          ...current.completedLessons,
          lesson,
        },
        laterLessons: <GuidanceLessonId>{...current.laterLessons}
          ..remove(lesson),
        replayLessons: current.replayLessons,
        expectedFirstRunCreatorTaskIds: current.expectedFirstRunCreatorTaskIds,
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
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
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
      ),
    );
  }

  /// An explicit "skip the walkthrough" for the whole first-run guide. It is
  /// stored as a skip, not a pause, and Settings can restart it.
  Future<void> skipCoreGuide() async {
    final String? account = _activeScope;
    if (account == null) return;
    await record(GuidanceMilestone.guidanceDismissed);
    if (_activeScope != account) return;
    final AdaptiveGuidanceState current = await _current();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String prefix = _prefix(account);
    for (final GuidanceLessonId id in _replayableCoreLessons) {
      await prefs.setBool('$prefix.skip.${id.name}', true);
      await prefs.remove('$prefix.later.${id.name}');
      await prefs.remove('$prefix.replay.${id.name}');
    }
    await prefs.remove('$prefix.$_expectedCreatorTaskIdsKey');
    if (!ref.mounted || _activeScope != account) return;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: <GuidanceLessonId>{
          ...current.skippedLessons,
          ..._replayableCoreLessons,
        },
        completedLessons: current.completedLessons,
        laterLessons: current.laterLessons.difference(_replayableCoreLessons),
        replayLessons: current.replayLessons.difference(_replayableCoreLessons),
        untilReopenedLessons: current.untilReopenedLessons,
        skippedCoreSteps: current.skippedCoreSteps,
      ),
    );
  }

  /// "Skip this step" on a first-run guide step: the guide moves on to its
  /// next step. Nothing is recorded as done or dismissed. When no step is
  /// left, the guide ends (reported as skipped) and its task list is cleared.
  Future<void> skipCoreStep(GuidanceLessonId lesson) async {
    final Set<GuidanceLessonId> stepLessons =
        AdaptiveGuidanceState._coreStepLessons(lesson);
    final String? account = _activeScope;
    if (account == null || stepLessons.isEmpty) return;
    final AdaptiveGuidanceState current = await _current();
    if (_activeScope != account) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    final String prefix = _prefix(account);
    for (final GuidanceLessonId id in stepLessons) {
      await prefs.setBool('$prefix.$_skipStepKey.${id.name}', true);
      await prefs.remove('$prefix.replay.${id.name}');
    }
    AdaptiveGuidanceState next = AdaptiveGuidanceState(
      milestones: current.milestones,
      counts: current.counts,
      skippedLessons: current.skippedLessons,
      completedLessons: current.completedLessons,
      laterLessons: current.laterLessons,
      replayLessons: current.replayLessons.difference(stepLessons),
      expectedFirstRunCreatorTaskIds: current.expectedFirstRunCreatorTaskIds,
      untilReopenedLessons: current.untilReopenedLessons,
      skippedCoreSteps: <GuidanceLessonId>{
        ...current.skippedCoreSteps,
        ...stepLessons,
      },
    );
    if (next.activeCoreLesson == null) {
      await prefs.remove('$prefix.$_expectedCreatorTaskIdsKey');
      next = AdaptiveGuidanceState(
        milestones: next.milestones,
        counts: next.counts,
        skippedLessons: next.skippedLessons,
        completedLessons: next.completedLessons,
        laterLessons: next.laterLessons,
        replayLessons: next.replayLessons,
        untilReopenedLessons: next.untilReopenedLessons,
        skippedCoreSteps: next.skippedCoreSteps,
      );
    }
    if (!ref.mounted || _activeScope != account) return;
    state = AsyncData(next);
  }

  /// Hides the core lesson until the app is next opened, without writing
  /// anything. Used when an explicit choice must not be mistaken for the
  /// tutorial exercise.
  Future<void> pauseCoreGuideUntilReopened() async {
    final String? account = _activeScope;
    if (account == null) return;
    final AdaptiveGuidanceState current = await _current();
    if (!ref.mounted || _activeScope != account) return;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: current.completedLessons,
        laterLessons: current.laterLessons,
        replayLessons: current.replayLessons,
        expectedFirstRunCreatorTaskIds: current.expectedFirstRunCreatorTaskIds,
        untilReopenedLessons: <GuidanceLessonId>{
          ...current.untilReopenedLessons,
          ..._replayableCoreLessons,
        },
        skippedCoreSteps: current.skippedCoreSteps,
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
      await prefs.remove('$prefix.$_skipStepKey.${id.name}');
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
    _ => GuidanceCatalogue.lessonCompletedBy(milestone),
  };
}
