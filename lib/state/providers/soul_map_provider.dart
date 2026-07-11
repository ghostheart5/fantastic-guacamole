import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_soul_layer.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/providers/core_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SoulMapProfileStore {
  const SoulMapProfileStore();

  static const String _key = 'soul_map_profile_v1';

  SoulMapProfile load() {
    final String? raw = SharedPrefsService.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return SoulMapProfile.empty();
    }
    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      return SoulMapProfile.fromJson(data);
    } catch (_) {
      return SoulMapProfile.empty();
    }
  }

  Future<void> save(SoulMapProfile profile) {
    return SharedPrefsService.save(_key, jsonEncode(profile.toJson()));
  }
}

final soulMapProfileStoreProvider = Provider<SoulMapProfileStore>((Ref _) {
  return const SoulMapProfileStore();
});

final soulMapProfileProvider =
    NotifierProvider<SoulMapProfileNotifier, SoulMapProfile>(
      SoulMapProfileNotifier.new,
    );

class SoulMapProfileNotifier extends Notifier<SoulMapProfile> {
  @override
  SoulMapProfile build() {
    return ref.read(soulMapProfileStoreProvider).load();
  }

  Future<void> setProfile(SoulMapProfile profile) async {
    state = profile;
    await ref.read(soulMapProfileStoreProvider).save(profile);
  }
}

final soulMapAlignmentProvider = Provider<SoulMapAlignment>((Ref ref) {
  final SoulMapProfile profile = ref.watch(soulMapProfileProvider);
  final SoulState soul = ref.watch(soulStateProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final goals = ref.watch(goalsProvider);
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  final int timelineHealth = ref.watch(timelineHealthScoreProvider);
  final int timelineRisk = ref.watch(timelineRiskScoreProvider);
  final int overdue = ref.watch(timelineOverdueProvider).length;
  final MilestoneSummary milestones = ref.watch(milestoneSummaryProvider);
  final CoreValuesAlignment coreValues = ref.watch(coreValuesAlignmentProvider);
  final int tasksCount = ref.watch(tasksProvider).asData?.value.length ?? 0;
  final double authoredBoost = (profile.authoredFieldCount * 1.8).clamp(
    0.0,
    18.0,
  );
  final double futureBoost =
      ((profile.futureSelfOneYear.isEmpty ? 0 : 5) +
              (profile.futureSelfFiveYears.isEmpty ? 0 : 5) +
              (profile.futureSelfTenYears.isEmpty ? 0 : 5))
          .toDouble();

  final int purpose = _score(
    35 +
        (goals.length * 7).clamp(0, 28) +
        (milestones.active * 4).clamp(0, 20) +
        (trajectory.momentum * 18) +
        (coreValues.scores[CoreValueType.purpose]?.score ?? 0) / 4 +
        (profile.purposeStatement.isEmpty ? 0 : 10),
  );

  final int identity = _score(
    34 +
        (soul.identityStrength * 36) +
        (soul.personalityGrowth * 20) +
        (coreValues.scores[CoreValueType.discipline]?.score ?? 0) / 5 +
        (profile.identityStatement.isEmpty ? 0 : 10),
  );

  final int futureSelf = _score(
    30 +
        (goals.length * 5).clamp(0, 20) +
        (milestones.upcoming * 6).clamp(0, 24) +
        (trajectory.momentum * 20) +
        (tasksCount > 0 ? 10 : 0) +
        futureBoost,
  );

  final int vision = _score(
    32 +
        (timelineHealth * 0.34) -
        (timelineRisk * 0.12) +
        (milestones.healthScore * 0.24) +
        (profile.visionStatement.isEmpty ? 0 : 10),
  );

  final int passionsSignals = memories.where((MemoryEntity memory) {
    final String text = memory.text.toLowerCase();
    return text.contains('love') ||
        text.contains('excited') ||
        text.contains('passion') ||
        text.contains('music') ||
        text.contains('build') ||
        text.contains('write') ||
        text.contains('create');
  }).length;

  final int passions = _score(
    26 +
        (passionsSignals * 7).clamp(0, 35) +
        (soul.userConnection * 22) +
        (profile.passionsStatement.isEmpty ? 0 : 10),
  );

  final int lifeStory = _score(
    30 +
        (soul.narrativePresence * 38) +
        (memories.length * 3).clamp(0, 24) +
        (soul.continuity * 15) +
        (profile.lifeStorySummary.isEmpty ? 0 : 10),
  );

  final int relationshipsSignals = memories.where((MemoryEntity memory) {
    final String text = memory.text.toLowerCase();
    return text.contains('family') ||
        text.contains('friend') ||
        text.contains('team') ||
        text.contains('partner') ||
        text.contains('relationship');
  }).length;

  final int relationships = _score(
    28 +
        (relationshipsSignals * 8).clamp(0, 40) +
        (coreValues.scores[CoreValueType.connection]?.score ?? 0) / 3 +
        (profile.relationshipsFocus.isEmpty ? 0 : 10),
  );

  final int legacy = _score(
    25 +
        (goals.length * 5).clamp(0, 20) +
        (milestones.completed * 5).clamp(0, 25) +
        (coreValues.scores[CoreValueType.purpose]?.score ?? 0) / 2 +
        (profile.legacyGoal.isEmpty ? 0 : 12),
  );

  final int reflections = _score(
    28 +
        (memories.length * 4).clamp(0, 28) +
        (soul.emotionalEvolution * 22) +
        (overdue == 0 ? 12 : 0) +
        (profile.reflectionsNotes.isEmpty ? 0 : 10),
  );

  final int growthJourney = _score(
    30 +
        (milestones.completed * 6).clamp(0, 30) +
        (trajectory.momentum * 24) +
        (coreValues.scores[CoreValueType.growth]?.score ?? 0) / 4,
  );

  final int lifeDirection = _score(
    34 +
        (timelineHealth * 0.26) +
        (coreValues.overall * 0.30) +
        (soul.continuity * 16) -
        (overdue * 4) +
        (profile.lifeDirectionStatement.isEmpty ? 0 : 12),
  );

  final Map<SoulMapDimension, int> raw = <SoulMapDimension, int>{
    SoulMapDimension.purpose: purpose,
    SoulMapDimension.identity: identity,
    SoulMapDimension.coreValues: coreValues.overall,
    SoulMapDimension.futureSelf: futureSelf,
    SoulMapDimension.vision: vision,
    SoulMapDimension.passions: passions,
    SoulMapDimension.lifeStory: lifeStory,
    SoulMapDimension.relationships: relationships,
    SoulMapDimension.legacy: legacy,
    SoulMapDimension.reflections: reflections,
    SoulMapDimension.growthJourney: growthJourney,
    SoulMapDimension.lifeDirection: lifeDirection,
  };

  final Map<SoulMapDimension, SoulMapDimensionScore> scores =
      <SoulMapDimension, SoulMapDimensionScore>{};
  for (final SoulMapDimension dimension in SoulMapDimension.values) {
    final SoulMapDimensionDefinition definition =
        soulMapDimensionDefinitions[dimension]!;
    scores[dimension] = SoulMapDimensionScore(
      dimension: dimension,
      score: raw[dimension] ?? 0,
      definition: definition,
    );
  }

  final List<MapEntry<SoulMapDimension, SoulMapDimensionScore>> ordered =
      scores.entries.toList(growable: false)
        ..sort((a, b) => b.value.score.compareTo(a.value.score));

  final int overall = ordered.isEmpty
      ? 0
      : _score(
          (ordered.map((entry) => entry.value.score).reduce((a, b) => a + b) /
                  ordered.length) +
              authoredBoost,
        );

  final SoulMapDimension strongest = ordered.first.key;
  final SoulMapDimension weakest = ordered.last.key;

  return SoulMapAlignment(
    scores: scores,
    overall: overall,
    strongest: strongest,
    weakest: weakest,
    recommendations: <String>[
      'Strongest area: ${soulMapDimensionTitle(strongest)}.',
      'Weakest area: ${soulMapDimensionTitle(weakest)}.',
      'Schedule one concrete action this week to strengthen ${soulMapDimensionTitle(weakest)}.',
    ],
  );
});

final soulMapSummaryProvider = Provider<SoulMapSummary>((Ref ref) {
  final SoulMapAlignment alignment = ref.watch(soulMapAlignmentProvider);
  final CoreValuesAlignment values = ref.watch(coreValuesAlignmentProvider);
  final SoulMapProfile profile = ref.watch(soulMapProfileProvider);
  final String strongest = soulMapDimensionTitle(alignment.strongest);
  final String weakest = soulMapDimensionTitle(alignment.weakest);

  return SoulMapSummary(
    definition: soulMapOneSentenceDefinition,
    purposeStatement: profile.purposeStatement.isEmpty
        ? 'Build a meaningful life through disciplined growth, creative contribution, and real connection.'
        : profile.purposeStatement,
    futureSelfVision:
        profile.futureSelfOneYear.isEmpty &&
            profile.futureSelfFiveYears.isEmpty &&
            profile.futureSelfTenYears.isEmpty
        ? 'Future self trend is ${alignment.scores[SoulMapDimension.futureSelf]?.score ?? 0}% aligned. Protect momentum and close the gap in $weakest.'
        : '1Y: ${_orPlaceholder(profile.futureSelfOneYear)} | 5Y: ${_orPlaceholder(profile.futureSelfFiveYears)} | 10Y: ${_orPlaceholder(profile.futureSelfTenYears)}',
    lifeDirectionStatement: profile.lifeDirectionStatement.isEmpty
        ? 'Current direction is ${alignment.overall}% aligned. Strongest compass signal: $strongest. Values anchor: ${coreValueTitle(values.strongest)}.'
        : profile.lifeDirectionStatement,
  );
});

final soulMapFutureSelfComparisonProvider = Provider<SoulMapFutureSelfComparison>((
  Ref ref,
) {
  final SoulMapAlignment alignment = ref.watch(soulMapAlignmentProvider);
  final SoulMapProfile profile = ref.watch(soulMapProfileProvider);

  final int current = _score(
    ((alignment.scores[SoulMapDimension.identity]?.score ?? 0) +
            (alignment.scores[SoulMapDimension.purpose]?.score ?? 0) +
            (alignment.scores[SoulMapDimension.lifeDirection]?.score ?? 0) +
            (alignment.scores[SoulMapDimension.coreValues]?.score ?? 0)) /
        4,
  );
  final int future = _score(
    ((alignment.scores[SoulMapDimension.futureSelf]?.score ?? 0) * 0.75) +
        ((profile.futureSelfOneYear.isEmpty ? 0 : 8) +
                (profile.futureSelfFiveYears.isEmpty ? 0 : 9) +
                (profile.futureSelfTenYears.isEmpty ? 0 : 10)) *
            1.0,
  );
  final int gap = (future - current).abs();
  final String stance = gap <= 8
      ? 'Aligned'
      : gap <= 20
      ? 'Moderate Gap'
      : 'High Gap';

  return SoulMapFutureSelfComparison(
    currentSelfAlignment: current,
    futureSelfReadiness: future,
    gap: gap,
    stance: stance,
    recommendation: gap <= 8
        ? 'Stay consistent. Keep validating major decisions against your 5-year self.'
        : 'Pick one weekly action that closes the Future Self gap and track it in milestones.',
  );
});

int _score(num value) => value.round().clamp(0, 100);

String _orPlaceholder(String value) =>
    value.trim().isEmpty ? 'not set' : value.trim();
