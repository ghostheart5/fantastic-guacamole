import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
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

final PersonContextAccessRequest _siV2PersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.siConsole,
      purposes: SIV2ReadGateway.personContextPurposes,
    );

/// Privacy-safe revision for the Person Context projection bound to SI V2.
///
/// The digest contains the complete projected state because SI V2 responses
/// may cite that projection as provenance. Raw context values never leave this
/// provider. Context outside the SI surface/purposes is absent from the view and
/// therefore cannot invalidate an SI response.
final siV2PersonContextRevisionProvider = Provider<String>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final String accountScopeId = assistantAccountScopeId(
    authenticatedNamespace: scope.v2Namespace,
    isSignedOut: scope.state == AccountStorageScopeState.signedOut,
  );
  final PersonContextView? view = ref.watch(
    personContextForSurfaceProvider(_siV2PersonContextRequest),
  );
  final SIV2PersonContextEvidence? evidence = siV2PersonContextEvidenceOrNull(
    view,
    accountScopeId: accountScopeId,
  );
  if (evidence == null) {
    return evidenceContentDigest(<String, Object?>{
      'contract': 'si-v2-person-context-revision-v1',
      'accountScopeId': accountScopeId,
      'status': 'unavailable',
    });
  }

  final List<String> unknownKinds =
      evidence.unknownKinds
          .map((PersonContextKind kind) => kind.name)
          .toList(growable: true)
        ..sort();
  return evidenceContentDigest(<String, Object?>{
    'contract': 'si-v2-person-context-revision-v1',
    'accountScopeId': accountScopeId,
    'status': evidence.signals.isEmpty ? 'known_empty' : 'available',
    'signals': evidence.signals
        .map(
          (SIV2PersonContextSignalEvidence signal) => <String, Object?>{
            'id': signal.id,
            'kind': signal.kind.name,
            'value': signal.userReportedValue,
            'source': signal.source.name,
            'purpose': signal.purpose.name,
            'recordedAt': signal.recordedAt.toUtc().toIso8601String(),
            'freshUntil': signal.freshUntil.toUtc().toIso8601String(),
            'expiresAt': signal.expiresAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false),
    'unknownKinds': unknownKinds,
  });
});

/// Composition root: SI V2 resolves only query use cases and reduces them to
/// read-only tear-offs. No repository or write-capable object crosses this boundary.
final siV2ReadGatewayProvider = Provider<SIV2ReadGateway>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final GetTasks tasks = ref.read(getTasksUseCaseProvider);
  final GetGoals goals = ref.read(getGoalsUseCaseProvider);
  final GetMilestones milestones = ref.read(getMilestonesUseCaseProvider);
  final GetTimelineEvents timeline = ref.read(getTimelineEventsUseCaseProvider);
  final PersonContextView? personContext = ref.watch(
    personContextForSurfaceProvider(_siV2PersonContextRequest),
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

/// The visible console is usable only when both its typed response path and
/// the safety critic are enabled for the current account cohort.
final siV2AvailabilityProvider = FutureProvider<bool>((Ref ref) async {
  final AssistantReleaseDecision console = await ref.watch(
    assistantReleaseDecisionProvider(
      AssistantReleaseCapability.siConsoleV2,
    ).future,
  );
  final AssistantReleaseDecision safety = await ref.watch(
    assistantReleaseDecisionProvider(
      AssistantReleaseCapability.safetyCritic,
    ).future,
  );
  return console.enabled && safety.enabled;
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
    this.readEvidenceForDecision,
  });

  final Future<SIV2EvidenceSnapshot> Function(DateTime observedAt) readEvidence;
  final DateTime Function() clock;
  final SIV2Engine engine;
  final Future<OperatingDecisionReceipt?> Function()? readDecisionReceipt;
  final Future<SIV2EvidenceSnapshot> Function(
    DateTime observedAt,
    String decisionText,
  )?
  readEvidenceForDecision;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    _requireSiEmotionalSafetyRoute(query.conversationText);
    final DateTime now = clock().toUtc();
    final SIV2EvidenceSnapshot snapshot =
        await readEvidenceForDecision?.call(now, query.conversationText) ??
        await readEvidence(now);
    SIV2Response response = engine.analyze(
      query: query,
      snapshot: snapshot,
      now: now,
    );
    final OperatingDecisionReceipt? sharedDecision = await readDecisionReceipt
        ?.call();
    final Set<String> siContextSignalIds =
        snapshot.personContext?.signals
            .map((SIV2PersonContextSignalEvidence signal) => signal.id)
            .toSet() ??
        const <String>{};
    if (sharedDecision != null &&
        (sharedDecision.personContextAppliedSignalIds.isEmpty ||
            siContextSignalIds.containsAll(
              sharedDecision.personContextAppliedSignalIds,
            ))) {
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
    readEvidenceForDecision: (DateTime observedAt, String decisionText) => ref
        .read(siV2ReadGatewayProvider)
        .read(observedAt: observedAt, decisionText: decisionText),
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
    _requireSiEmotionalSafetyRoute(query.conversationText);
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

void _requireSiEmotionalSafetyRoute(String input) {
  final EmotionalSafetyAssessment safety = EmotionalSafetyPolicy.assess(input);
  if (safety.requiresImmediateSafety) {
    throw const AssistantSafetyRouteException(
      'crisis_route_required',
      'SI Console must show the dedicated crisis support route.',
    );
  }
  if (safety.requiresSupportivePause) {
    throw const AssistantSafetyRouteException(
      'distress_route_required',
      'SI Console must show the dedicated non-crisis support route.',
    );
  }
}
