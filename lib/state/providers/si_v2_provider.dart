import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/milestone_usecases.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siV2ClockProvider = Provider<DateTime Function()>(
  (Ref ref) =>
      () => DateTime.now().toUtc(),
);

/// Composition root: SI V2 resolves only query use cases and reduces them to
/// read-only tear-offs. No repository or write-capable object crosses this boundary.
final siV2ReadGatewayProvider = Provider<SIV2ReadGateway>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final GetTasks tasks = ref.read(getTasksUseCaseProvider);
  final GetGoals goals = ref.read(getGoalsUseCaseProvider);
  final GetMilestones milestones = ref.read(getMilestonesUseCaseProvider);
  final GetTimelineEvents timeline = ref.read(getTimelineEventsUseCaseProvider);
  final PersonContextView? personContext = ref.watch(
    personContextForSurfaceProvider(
      PersonContextAccessRequest(
        surface: PersonContextSurface.siConsole,
        purposes: SIV2ReadGateway.personContextPurposes,
      ),
    ),
  );
  return SIV2ReadGateway(
    accountScopeId: assistantAccountScopeId(
      authenticatedNamespace: scope.v2Namespace,
      isSignedOut: scope.state == AccountStorageScopeState.signedOut,
    ),
    readTasks: tasks.call,
    readGoals: () async => goals.call(),
    readMilestones: milestones.call,
    readTimeline: () async => timeline.call(),
    readPersonContext: () => personContext,
  );
});

final siV2EvidenceSnapshotProvider = FutureProvider<SIV2EvidenceSnapshot>((
  Ref ref,
) {
  return ref
      .watch(siV2ReadGatewayProvider)
      .read(observedAt: ref.watch(siV2ClockProvider)());
});

abstract interface class SIV2QueryPort {
  Future<SIV2Response> analyze(SIV2Query query);
}

final class SIV2QueryService implements SIV2QueryPort {
  const SIV2QueryService({
    required this.readEvidence,
    required this.clock,
    this.engine = const SIV2Engine(),
    this.readDecisionReceipt,
  });

  final Future<SIV2EvidenceSnapshot> Function(DateTime observedAt) readEvidence;
  final DateTime Function() clock;
  final SIV2Engine engine;
  final Future<OperatingDecisionReceipt?> Function()? readDecisionReceipt;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    if (CrisisDetectionPolicy.detects(query.conversationText)) {
      throw const AssistantSafetyRouteException(
        'crisis_route_required',
        'SI Console must show the dedicated crisis support route.',
      );
    }
    final DateTime now = clock().toUtc();
    final SIV2EvidenceSnapshot snapshot = await readEvidence(now);
    SIV2Response response = engine.analyze(
      query: query,
      snapshot: snapshot,
      now: now,
    );
    final OperatingDecisionReceipt? sharedDecision = await readDecisionReceipt
        ?.call();
    if (sharedDecision != null) {
      response = response.withOperatingDecision(sharedDecision, now: now);
    }
    final String responseText = response.toPlainText();
    final AssistantSafetyRisk risk = switch (query.intent) {
      SIV2Intent.forecast ||
      SIV2Intent.counterfactual => AssistantSafetyRisk.highImpact,
      _ when response.conflicts.isNotEmpty => AssistantSafetyRisk.contradictory,
      _ => AssistantSafetyRisk.routine,
    };
    final AssistantSafetyOutcome safety = const AssistantSafetyPipeline()
        .evaluate(
          AssistantSafetyReview(
            requestId:
                'si-v2-${snapshot.revision.substring(0, 16)}-'
                '${now.microsecondsSinceEpoch}',
            accountScopeId: snapshot.accountScopeId,
            surface: AssistantSafetySurface.siConsole,
            responseText: responseText,
            evidenceIds: response.evidenceLinks.map(
              (SIV2EvidenceLink item) => item.evidenceId,
            ),
            evidenceUris: response.evidenceLinks.map(
              (SIV2EvidenceLink item) => item.uri,
            ),
            untrustedData: <String>[
              ...snapshot.tasks.map((SIV2TaskEvidence item) => item.title),
              ...snapshot.goals.map((SIV2GoalEvidence item) => item.title),
              ...snapshot.milestones.map(
                (SIV2MilestoneEvidence item) => item.title,
              ),
              ...snapshot.timeline.map(
                (SIV2TimelineEvidence item) => item.title,
              ),
              ...?snapshot.personContext?.signals.map(
                (SIV2PersonContextSignalEvidence item) =>
                    item.userReportedValue,
              ),
            ],
            authority: AssistantActionAuthority.readOnly,
            risk: risk,
            contradictionCount: response.conflicts.length,
          ),
        );
    if (!safety.mayPublish || safety.publishableText != responseText) {
      throw const AssistantSafetyRouteException(
        'si_response_withheld',
        'SI V2 withheld a draft that could not be safely repaired into its typed contract.',
      );
    }
    return response.withSafetyReceipt(safety.receipt);
  }
}

final siV2QueryServiceProvider = Provider<SIV2QueryPort>((Ref ref) {
  final SIV2QueryPort delegate = SIV2QueryService(
    readEvidence: (DateTime observedAt) =>
        ref.read(siV2ReadGatewayProvider).read(observedAt: observedAt),
    clock: ref.watch(siV2ClockProvider),
    readDecisionReceipt: () async {
      try {
        final SurfaceDecisionReceipt surface = await ref.read(
          operatingDecisionForSurfaceProvider(
            OperatingDecisionSurface.siConsole,
          ).future,
        );
        return surface.receipt;
      } on Object {
        return null;
      }
    },
  );
  return _ReleaseControlledSIV2QueryPort(ref, delegate: delegate);
});

final class _ReleaseControlledSIV2QueryPort implements SIV2QueryPort {
  const _ReleaseControlledSIV2QueryPort(this._ref, {required this.delegate});

  final Ref _ref;
  final SIV2QueryPort delegate;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    if (CrisisDetectionPolicy.detects(query.conversationText)) {
      throw const AssistantSafetyRouteException(
        'crisis_route_required',
        'SI Console must show the dedicated crisis support route.',
      );
    }
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.siConsoleV2,
    );
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.safetyCritic,
    );
    return delegate.analyze(query);
  }
}
