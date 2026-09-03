import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/persisted_payload_failure.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String personalizationProfileStorageKey = 'personalization_profile_v1';
const String observedPlanningPatternsStorageKey =
    'observed_planning_patterns_v1';

final personalizationProfileProvider =
    NotifierProvider<PersonalizationProfileController, PersonalizationProfile>(
      PersonalizationProfileController.new,
    );

final observedPlanningPatternsProvider =
    NotifierProvider<
      ObservedPlanningPatternsController,
      ObservedPlanningPatterns
    >(ObservedPlanningPatternsController.new);

final adaptivePlanPolicyProvider = Provider<AdaptivePlanPolicy>((Ref ref) {
  final PersonalizationProfile profile = ref.watch(
    personalizationProfileProvider,
  );
  return adaptivePlanPolicyFor(profile);
});

AdaptivePlanPolicy adaptivePlanPolicyFor(PersonalizationProfile profile) {
  final ({
    double priority,
    double deadline,
    double energy,
    double goal,
    double quickWin,
  })
  strategy = switch (profile.priorityStrategy) {
    PriorityStrategy.deadlineFirst => (
      priority: 1,
      deadline: 2.25,
      energy: 1,
      goal: 0,
      quickWin: 0,
    ),
    PriorityStrategy.energyFirst => (
      priority: 1,
      deadline: 1,
      energy: 2.25,
      goal: 0,
      quickWin: 0,
    ),
    PriorityStrategy.goalFirst => (
      priority: 1,
      deadline: 1,
      energy: 1,
      goal: 18,
      quickWin: 0,
    ),
    PriorityStrategy.quickWins => (
      priority: 1,
      deadline: 1,
      energy: 1,
      goal: 0,
      quickWin: 18,
    ),
    PriorityStrategy.balanced => (
      priority: 1,
      deadline: 1,
      energy: 1,
      goal: 0,
      quickWin: 0,
    ),
  };
  final bool energyMatched =
      profile.planningStyle == PlanningStyle.energyMatched;
  final bool singleTask = profile.planningStyle == PlanningStyle.singleTask;
  final bool fixedBlocks =
      profile.planningStyle == PlanningStyle.timeBlocked || singleTask;
  return AdaptivePlanPolicy(
    priorityWeight: strategy.priority * (singleTask ? 1.4 : 1),
    deadlineWeight: strategy.deadline,
    energyWeight: strategy.energy * (energyMatched ? 1.75 : 1),
    goalBonus: strategy.goal,
    quickWinBonus: strategy.quickWin,
    adaptDurationToEnergy: !fixedBlocks,
    fixedBreakMinutes: singleTask
        ? 15
        : profile.planningStyle == PlanningStyle.timeBlocked
        ? 10
        : null,
  );
}

class PersonalizationProfileController
    extends Notifier<PersonalizationProfile> {
  late SharedPrefsStore _store;

  @override
  PersonalizationProfile build() {
    _store = AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: ref.watch(accountStorageScopeProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    );
    unawaited(_load());
    return const PersonalizationProfile();
  }

  Future<void> _load() async {
    await _store.init();
    final String? raw = _store.load(personalizationProfileStorageKey);
    if (!ref.mounted || raw == null || raw.trim().isEmpty) return;
    try {
      state = PersonalizationProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (error, stackTrace) {
      try {
        handlePersistedPayloadDecodeFailure(
          diagnosticCode: 'storage.personalization_profile_decode_failed',
          error: error,
          stackTrace: stackTrace,
        );
      } on Object {
        Logger.recordDiagnosticCode(
          code: 'storage.personalization_profile_load_failed',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> update(PersonalizationProfile next) async {
    final DateTime now = DateTime.now().toUtc();
    final bool emotionEnabled = next.useEmotionSignals;
    final bool memoryEnabled = next.useMemoryContext;
    final PersonalizationProfile reviewed = next.copyWith(
      emotionConsentGrantedAt: emotionEnabled
          ? state.emotionConsentGrantedAt ?? now
          : null,
      memoryConsentGrantedAt: memoryEnabled
          ? state.memoryConsentGrantedAt ?? now
          : null,
      clearEmotionConsent: !emotionEnabled,
      clearMemoryConsent: !memoryEnabled,
      lastReviewedAt: now,
    );
    state = reviewed;
    await _store.save(
      personalizationProfileStorageKey,
      jsonEncode(reviewed.toJson()),
    );
  }

  Future<void> updateGoalCategory(String value) =>
      update(state.copyWith(goalCategory: value.trim()));

  Future<void> reset() async {
    state = const PersonalizationProfile();
    await _store.delete(personalizationProfileStorageKey);
  }
}

class ObservedPlanningPatternsController
    extends Notifier<ObservedPlanningPatterns> {
  late SharedPrefsStore _store;

  @override
  ObservedPlanningPatterns build() {
    _store = AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: ref.watch(accountStorageScopeProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    );
    unawaited(_load());
    return const ObservedPlanningPatterns();
  }

  Future<void> _load() async {
    await _store.init();
    final String? raw = _store.load(observedPlanningPatternsStorageKey);
    if (!ref.mounted || raw == null || raw.trim().isEmpty) return;
    try {
      state = ObservedPlanningPatterns.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (error, stackTrace) {
      try {
        handlePersistedPayloadDecodeFailure(
          diagnosticCode: 'storage.planning_patterns_decode_failed',
          error: error,
          stackTrace: stackTrace,
        );
      } on Object {
        Logger.recordDiagnosticCode(
          code: 'storage.planning_patterns_load_failed',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _persist(ObservedPlanningPatterns next) async {
    state = next;
    await _store.save(
      observedPlanningPatternsStorageKey,
      jsonEncode(next.toJson()),
    );
  }

  Future<void> recordCompletion({required int difficulty}) => _persist(
    state.copyWith(
      completed: state.completed + 1,
      shortTaskCompletions:
          state.shortTaskCompletions + (difficulty <= 2 ? 1 : 0),
      deepTaskCompletions:
          state.deepTaskCompletions + (difficulty >= 4 ? 1 : 0),
      lastUpdatedAt: DateTime.now(),
    ),
  );

  Future<void> recordSkip() => _persist(
    state.copyWith(skipped: state.skipped + 1, lastUpdatedAt: DateTime.now()),
  );

  Future<void> reset() async {
    state = const ObservedPlanningPatterns();
    await _store.delete(observedPlanningPatternsStorageKey);
  }
}

final personalizationDecisionProvider =
    Provider.family<PersonalizationDecision, String>((ref, surface) {
      final PersonalizationProfile profile = ref.watch(
        personalizationProfileProvider,
      );
      final ObservedPlanningPatterns patterns = ref.watch(
        observedPlanningPatternsProvider,
      );
      final List<String> signals = <String>[
        if (profile.goalCategory.isNotEmpty) 'goal category',
        'planning style: ${profile.planningStyle.name}',
        'priority strategy: ${profile.priorityStrategy.name}',
        if (patterns.completed + patterns.skipped > 0)
          'completion history (${(patterns.completionRate * 100).round()}%)',
      ];
      return PersonalizationDecision(
        surface: surface,
        signalsUsed: signals,
        confidence: ((patterns.completed + patterns.skipped) / 20).clamp(
          0.0,
          1.0,
        ),
        explanation: signals.isEmpty
            ? 'Using safe defaults until you provide more planning context.'
            : 'Uses ${signals.join(', ')}. You can change these choices in Settings.',
      );
    });
