import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
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

class PersonalizationProfileController
    extends Notifier<PersonalizationProfile> {
  @override
  PersonalizationProfile build() {
    _load();
    return const PersonalizationProfile();
  }

  Future<void> _load() async {
    await SharedPrefsService.init();
    final String? raw = SharedPrefsService.load(
      personalizationProfileStorageKey,
    );
    if (!ref.mounted || raw == null || raw.trim().isEmpty) return;
    try {
      state = PersonalizationProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Preserve safe defaults and leave the corrupt payload recoverable.
    }
  }

  Future<void> update(PersonalizationProfile next) async {
    final PersonalizationProfile reviewed = next.copyWith(
      lastReviewedAt: DateTime.now(),
    );
    state = reviewed;
    await SharedPrefsService.save(
      personalizationProfileStorageKey,
      jsonEncode(reviewed.toJson()),
    );
  }

  Future<void> updateGoalCategory(String value) =>
      update(state.copyWith(goalCategory: value.trim()));

  Future<void> reset() async {
    state = const PersonalizationProfile();
    await SharedPrefsService.delete(personalizationProfileStorageKey);
  }
}

class ObservedPlanningPatternsController
    extends Notifier<ObservedPlanningPatterns> {
  @override
  ObservedPlanningPatterns build() {
    _load();
    return const ObservedPlanningPatterns();
  }

  Future<void> _load() async {
    await SharedPrefsService.init();
    final String? raw = SharedPrefsService.load(
      observedPlanningPatternsStorageKey,
    );
    if (!ref.mounted || raw == null || raw.trim().isEmpty) return;
    try {
      state = ObservedPlanningPatterns.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Preserve safe defaults.
    }
  }

  Future<void> _persist(ObservedPlanningPatterns next) async {
    state = next;
    await SharedPrefsService.save(
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
    await SharedPrefsService.delete(observedPlanningPatternsStorageKey);
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
