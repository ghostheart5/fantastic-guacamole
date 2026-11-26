import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Answers a one-tap question on the device. There is no remote variant: the
/// port has no network, wallet or paid-request dependency at all.
abstract interface class SIOneTapPort {
  Future<SIOneTapAnswer> answer(
    SIOneTapQuestion question, {
    required bool isSpanish,
    String? goalId,
  });
}

final class SIOneTapService implements SIOneTapPort {
  const SIOneTapService({
    required this.readEvidence,
    required this.clock,
    this.engine = const SIOneTapEngine(),
  });

  final Future<SIV2EvidenceSnapshot> Function(DateTime observedAt) readEvidence;
  final DateTime Function() clock;
  final SIOneTapEngine engine;

  @override
  Future<SIOneTapAnswer> answer(
    SIOneTapQuestion question, {
    required bool isSpanish,
    String? goalId,
  }) async {
    final DateTime now = clock().toUtc();
    final SIV2EvidenceSnapshot snapshot = await readEvidence(now);
    final SIOneTapAnswer draft = engine.answer(
      question: question,
      snapshot: snapshot,
      now: now,
      isSpanish: isSpanish,
      goalId: goalId,
    );
    final SIV2Response response = draft.response;
    final String responseText = response.toPlainText();
    // The same safety pass every on-device answer goes through. The person's
    // own words in titles stay untrusted data.
    final AssistantSafetyOutcome safety = const AssistantSafetyPipeline()
        .evaluate(
          AssistantSafetyReview(
            requestId:
                'si-one-tap-${snapshot.revision.substring(0, 16)}-'
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
              ...snapshot.habits.map((SIV2HabitEvidence item) => item.title),
              ...snapshot.recentTasks.map(
                (SIV2RecentTaskEvidence item) => item.title,
              ),
            ],
            authority: AssistantActionAuthority.readOnly,
            risk: AssistantSafetyRisk.routine,
            contradictionCount: 0,
          ),
        );
    if (!safety.mayPublish || safety.publishableText != responseText) {
      throw const AssistantSafetyRouteException(
        'si_response_withheld',
        'A one-tap answer was withheld by the safety check.',
      );
    }
    return SIOneTapAnswer(
      question: draft.question,
      response: response.withSafetyReceipt(safety.receipt),
      offerAddSomething: draft.offerAddSomething,
      offerAi: draft.offerAi,
    );
  }
}

final class _ReleaseControlledOneTapPort implements SIOneTapPort {
  const _ReleaseControlledOneTapPort(this._ref, this._delegate);

  final Ref _ref;
  final SIOneTapPort _delegate;

  @override
  Future<SIOneTapAnswer> answer(
    SIOneTapQuestion question, {
    required bool isSpanish,
    String? goalId,
  }) async {
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.siConsoleV2,
    );
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.safetyCritic,
    );
    return _delegate.answer(question, isSpanish: isSpanish, goalId: goalId);
  }
}

final siOneTapServiceProvider = Provider<SIOneTapPort>((Ref ref) {
  return _ReleaseControlledOneTapPort(
    ref,
    SIOneTapService(
      readEvidence: (DateTime observedAt) => ref
          .read(siV2ReadGatewayProvider)
          .read(observedAt: observedAt, includeActivity: true),
      clock: ref.watch(siV2ClockProvider),
    ),
  );
});

/// A one-tap question waiting to be answered by the free Chat console, for
/// example one tapped on Today. Holds only which question; it starts empty
/// again for another account.
final class SIOneTapRequest {
  const SIOneTapRequest(this.question, this.serial);

  final SIOneTapQuestion question;
  final int serial;
}

class SIOneTapRequestController extends Notifier<SIOneTapRequest?> {
  int _serial = 0;

  @override
  SIOneTapRequest? build() {
    ref.watch(accountStorageScopeProvider.select((scope) => scope.v2Namespace));
    return null;
  }

  void ask(SIOneTapQuestion question) =>
      state = SIOneTapRequest(question, ++_serial);

  void clear() => state = null;
}

final siOneTapRequestProvider =
    NotifierProvider<SIOneTapRequestController, SIOneTapRequest?>(
      SIOneTapRequestController.new,
    );
