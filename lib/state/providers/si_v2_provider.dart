import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/milestone_usecases.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
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
  return SIV2ReadGateway(
    accountScopeId: assistantAccountScopeId(
      authenticatedNamespace: scope.v2Namespace,
      isSignedOut: scope.state == AccountStorageScopeState.signedOut,
    ),
    readTasks: tasks.call,
    readGoals: () async => goals.call(),
    readMilestones: milestones.call,
    readTimeline: () async => timeline.call(),
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
  });

  final Future<SIV2EvidenceSnapshot> Function(DateTime observedAt) readEvidence;
  final DateTime Function() clock;
  final SIV2Engine engine;

  @override
  Future<SIV2Response> analyze(SIV2Query query) async {
    final DateTime now = clock().toUtc();
    final SIV2EvidenceSnapshot snapshot = await readEvidence(now);
    return engine.analyze(query: query, snapshot: snapshot, now: now);
  }
}

final siV2QueryServiceProvider = Provider<SIV2QueryPort>((Ref ref) {
  return SIV2QueryService(
    readEvidence: (DateTime observedAt) =>
        ref.read(siV2ReadGatewayProvider).read(observedAt: observedAt),
    clock: ref.watch(siV2ClockProvider),
  );
});
