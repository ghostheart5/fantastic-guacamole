import 'dart:async';

import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/nexus_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final bool capability in <bool>[false, true]) {
    for (final bool enabled in <bool>[false, true]) {
      test(
        'offline queue respects capability=$capability and opt-in=$enabled',
        () async {
          final ProviderContainer container = await _container(
            capability: capability,
            enabled: enabled,
          );
          final NexusDecisionModel model = container.read(
            nexusDecisionProvider,
          );

          expect(model.status, NexusDecisionStatus.offline);
          expect(model.pendingSyncCount, 2);
          expect(
            model.statusDetail,
            contains('2 changes remain queued on this device.'),
          );
          expect(model.statusDetail, isNot(contains('will synchronize')));
          expect(
            model.statusDetail,
            contains(
              !capability
                  ? 'Cloud synchronization is unavailable in this build.'
                  : enabled
                  ? 'Cloud synchronization is enabled and requires a connection to the service.'
                  : 'Cloud synchronization is turned off in Settings.',
            ),
          );
        },
      );
    }
  }

  test('does not reuse previous opt-in while preference is loading', () async {
    final ProviderContainer container = await _container(pendingCount: 1);
    container.read(nexusDecisionProvider);
    final _CloudSyncPreferenceNotifier preference =
        container.read(cloudSyncPreferenceProvider.notifier)
            as _CloudSyncPreferenceNotifier;
    final Completer<bool> refreshedPreference = Completer<bool>();
    preference.nextBuild = refreshedPreference.future;
    container.invalidate(cloudSyncPreferenceProvider);
    final AsyncValue<bool> loadingPreference = container.read(
      cloudSyncPreferenceProvider,
    );
    expect(loadingPreference.isLoading, isTrue);
    expect(loadingPreference.asData?.value, isTrue);

    final NexusDecisionModel model = container.read(nexusDecisionProvider);
    expect(model.pendingSyncCount, 1);
    expect(
      model.statusDetail,
      contains('1 change remains queued on this device.'),
    );
    expect(model.statusDetail, contains('preference is still being checked.'));
    expect(model.statusDetail, isNot(contains('synchronization is enabled')));

    refreshedPreference.complete(false);
    await container.read(cloudSyncPreferenceProvider.future);
    expect(
      container.read(nexusDecisionProvider).statusDetail,
      contains('Cloud synchronization is turned off in Settings.'),
    );
  });

  test(
    'reports unavailable preference without promising synchronization',
    () async {
      final ProviderContainer container = await _container();
      container.read(nexusDecisionProvider);
      (container.read(cloudSyncPreferenceProvider.notifier)
              as _CloudSyncPreferenceNotifier)
          .setValue(
            AsyncError<bool>(StateError('test failure'), StackTrace.current),
          );

      final NexusDecisionModel model = container.read(nexusDecisionProvider);
      expect(model.status, NexusDecisionStatus.offline);
      expect(model.pendingSyncCount, 2);
      expect(
        model.statusDetail,
        contains('Cloud synchronization preference is unavailable.'),
      );
      expect(model.statusDetail, isNot(contains('will synchronize')));
    },
  );

  test('keeps the normal available-interface summary', () async {
    final ProviderContainer container = await _container(
      capability: false,
      enabled: false,
      availability: NetworkInterfaceAvailability.available,
    );
    final NexusDecisionModel model = container.read(nexusDecisionProvider);

    expect(model.status, NexusDecisionStatus.ready);
    expect(model.pendingSyncCount, 2);
    expect(
      model.statusDetail,
      'Your planning summary is available on this device.',
    );
  });

  test('keeps offline summary when there are no queued changes', () async {
    final ProviderContainer container = await _container(pendingCount: 0);
    final NexusDecisionModel model = container.read(nexusDecisionProvider);

    expect(model.status, NexusDecisionStatus.offline);
    expect(model.pendingSyncCount, 0);
    expect(
      model.statusDetail,
      'No network interface is available. Using local evidence without network-backed freshness.',
    );
  });
}

Future<ProviderContainer> _container({
  bool capability = true,
  bool enabled = true,
  int pendingCount = 2,
  NetworkInterfaceAvailability availability =
      NetworkInterfaceAvailability.unavailable,
}) async {
  final ProviderContainer container = ProviderContainer(
    retry: (int retryCount, Object error) => null,
    overrides: [
      decisionIntelligenceProvider.overrideWith((Ref ref) => _intelligence()),
      progressionProvider.overrideWithValue(ProgressionState.initial()),
      progressionIntelligenceProvider.overrideWithValue(
        const ProgressionIntelligence(
          status: 'Baseline pending',
          changedSincePriorWindow: 'No prior window.',
          whyItMatters: 'Observed completions support planning.',
          nextBestAction: 'Complete the next action.',
          confidence: PredictiveConfidenceProfile(
            sourceCompleteness: .25,
            freshness: .35,
            sampleSufficiency: 0,
            intervalPrecision: .2,
          ),
          evidence: <String>[],
        ),
      ),
      dailyDecisionIntelligenceProvider.overrideWithValue(
        const DailyDecisionIntelligence(
          primaryAction: 'Review the plan',
          momentum: 'Baseline pending',
          trajectory: 'Baseline pending',
          energy: 'Energy not checked',
          warning: 'No material constraint is supported.',
          recovery: 'Unobserved',
          recommendedAction: 'Review the plan',
          rationale: 'Current evidence is available.',
          changeSummary: 'No prior window.',
          evidence: <String>[],
          confidence: .2,
          observedOutcomes: 0,
        ),
      ),
      networkInterfaceAvailabilityProvider.overrideWithValue(availability),
      offlineQueueCountProvider.overrideWith((Ref ref) => pendingCount),
      cloudSyncCapabilityProvider.overrideWithValue(capability),
      cloudSyncPreferenceProvider.overrideWith(
        () => _CloudSyncPreferenceNotifier(enabled),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(decisionIntelligenceProvider.future);
  await container.read(offlineQueueCountProvider.future);
  await container.read(cloudSyncPreferenceProvider.future);
  return container;
}

class _CloudSyncPreferenceNotifier extends CloudSyncPreferenceNotifier {
  _CloudSyncPreferenceNotifier(this.enabled);

  final bool enabled;
  Future<bool>? nextBuild;

  @override
  Future<bool> build() => nextBuild ?? Future<bool>.value(enabled);

  void setValue(AsyncValue<bool> value) => state = value;
}

DecisionIntelligence _intelligence() {
  final DateTime now = DateTime.utc(2026, 9, 5);
  final OperatingSnapshot snapshot = OperatingSnapshot(
    accountScope: 'nexus-test-account',
    observedAt: now,
    sourceRevisions: const <String, String>{'tasks': '1'},
    activeGoalCount: 0,
    actionableCount: 1,
    overdueCount: 0,
    completedToday: 0,
    energy: .5,
    fatigue: .5,
    momentum: 0,
    pressure: 0,
    topActionId: 'task-1',
    topActionLabel: 'Review the plan',
    activeRisks: const <String>[],
    evidenceCoverage: .5,
  );
  return DecisionIntelligence(
    snapshot: snapshot,
    delta: const OperatingDeltaEngine().compare(
      previous: null,
      current: snapshot,
      comparedAt: now,
    ),
    decision: OperatingDecisionReceipt(
      subjectId: 'task-1',
      recommendedAction: 'Review the plan',
      rationale: 'Current evidence is available.',
      whyItMatters: 'Keeps the plan current.',
      consequenceOfDelay: 'The plan may become stale.',
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
      confidence: OperatingConfidence.low,
      evidence: const <OperatingEvidence>[],
      actionIntent: const OperatingActionIntent(
        id: 'open-timeline',
        type: OperatingActionType.openTimeline,
        label: 'Review on Timeline',
        destination: '/timeline',
      ),
      sourceRevisions: snapshot.sourceRevisions,
      modelVersion: 'test',
    ),
    acknowledgedSnapshotId: null,
  );
}
