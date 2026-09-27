import 'dart:async';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer configured({
    bool proxyAvailable = true,
    bool creditSpendingAvailable = true,
    AccountStorageScope? scope,
    AssistantReleaseConfig? release,
    bool betaOptIn = false,
    Completer<AssistantReleaseDecision>? delayedSafety,
  }) => ProviderContainer(
    overrides: [
      for (final capability in AssistantReleaseCapability.values)
        assistantReleaseDecisionProvider(capability).overrideWith((ref) async {
          if (capability == AssistantReleaseCapability.safetyCritic &&
              delayedSafety != null) {
            return delayedSafety.future;
          }
          return const AssistantReleaseController().decide(
            config: release ?? configuration(),
            request: AssistantReleaseRequest(
              accountScopeId:
                  ref.watch(accountStorageScopeProvider).v2Namespace ??
                  'v2.unsafe',
              capability: capability,
              betaOptIn: betaOptIn,
            ),
          );
        }),
      internalCreditTestEnabledProvider.overrideWithValue(false),
      aiProxyAvailableProvider.overrideWithValue(proxyAvailable),
      creditSpendingAvailableProvider.overrideWithValue(
        creditSpendingAvailable,
      ),
      accountStorageScopeProvider.overrideWithValue(
        scope ?? AccountStorageScope.authenticated('public-review-account'),
      ),
    ],
  );

  test('public conversations do not require private tester membership', () {
    final container = configured();
    addTearDown(container.dispose);
    expect(container.read(internalCreditTestEnabledProvider), isFalse);
    expect(container.read(assistantConversationAvailableProvider), isTrue);
  });

  test('conversations require both reviewed proxy and credit availability', () {
    for (final flags in [(false, true), (true, false), (false, false)]) {
      final container = configured(
        proxyAvailable: flags.$1,
        creditSpendingAvailable: flags.$2,
      );
      addTearDown(container.dispose);
      expect(container.read(assistantConversationAvailableProvider), isFalse);
    }
  });

  test('signed-out and unsafe account scopes cannot open conversations', () {
    for (final scope in [
      const AccountStorageScope.signedOut(),
      const AccountStorageScope.unsafe(),
    ]) {
      final container = configured(scope: scope);
      addTearDown(container.dispose);
      expect(container.read(assistantConversationAvailableProvider), isFalse);
    }
  });
  Future<void> settle(ProviderContainer container) async {
    for (final capability in [
      AssistantReleaseCapability.smartPlannerV2,
      AssistantReleaseCapability.siConsoleV2,
      AssistantReleaseCapability.safetyCritic,
    ]) {
      await container.read(assistantReleaseDecisionProvider(capability).future);
    }
    await container.pump();
  }

  test('general public routes enable both reviewed surfaces', () async {
    final container = configured();
    addTearDown(container.dispose);
    await settle(container);
    for (final surface in ConversationSurface.values) {
      expect(
        container.read(assistantConversationSurfaceAvailableProvider(surface)),
        isTrue,
      );
    }
  });

  for (final stage in [
    AssistantReleaseStage.off,
    AssistantReleaseStage.internal,
    AssistantReleaseStage.optedInBeta,
    AssistantReleaseStage.canary,
  ]) {
    test('excluded ${stage.name} users retain local tools', () async {
      final container = configured(release: configuration(stage: stage));
      addTearDown(container.dispose);
      await settle(container);
      expect(container.read(assistantConversationAvailableProvider), isTrue);
      for (final surface in ConversationSurface.values) {
        expect(
          container.read(
            assistantConversationSurfaceAvailableProvider(surface),
          ),
          isFalse,
        );
      }
    });
  }

  test('a surface rollback does not disable the other surface', () async {
    for (final capability in [
      AssistantReleaseCapability.smartPlannerV2,
      AssistantReleaseCapability.siConsoleV2,
    ]) {
      final container = configured(
        release: configuration(rollback: {capability}),
      );
      addTearDown(container.dispose);
      await settle(container);
      expect(
        container.read(
          assistantConversationSurfaceAvailableProvider(
            ConversationSurface.planner,
          ),
        ),
        capability != AssistantReleaseCapability.smartPlannerV2,
      );
      expect(
        container.read(
          assistantConversationSurfaceAvailableProvider(ConversationSurface.si),
        ),
        capability != AssistantReleaseCapability.siConsoleV2,
      );
    }
  });

  test('safety rollback blocks both conversation routes', () async {
    final container = configured(
      release: configuration(
        rollback: {AssistantReleaseCapability.safetyCritic},
      ),
    );
    addTearDown(container.dispose);
    await settle(container);
    for (final surface in ConversationSurface.values) {
      expect(
        container.read(assistantConversationSurfaceAvailableProvider(surface)),
        isFalse,
      );
    }
  });

  test(
    'unresolved safety retains local tools until approval arrives',
    () async {
      final delayed = Completer<AssistantReleaseDecision>();
      final container = configured(delayedSafety: delayed);
      addTearDown(container.dispose);
      final provider = assistantConversationSurfaceAvailableProvider(
        ConversationSurface.planner,
      );
      container.listen(provider, (_, _) {});
      await container.read(
        assistantReleaseDecisionProvider(
          AssistantReleaseCapability.smartPlannerV2,
        ).future,
      );
      expect(container.read(provider), isFalse);
      delayed.complete(
        const AssistantReleaseController().decide(
          config: configuration(),
          request: const AssistantReleaseRequest(
            accountScopeId: 'v2.public-review-account',
            capability: AssistantReleaseCapability.safetyCritic,
            betaOptIn: false,
          ),
        ),
      );
      await container.read(
        assistantReleaseDecisionProvider(
          AssistantReleaseCapability.safetyCritic,
        ).future,
      );
      await container.pump();
      expect(container.read(provider), isTrue);
    },
  );
}

AssistantReleaseConfig configuration({
  AssistantReleaseStage stage = AssistantReleaseStage.general,
  Set<AssistantReleaseCapability> rollback = const {},
}) => AssistantReleaseConfig(
  stage: stage,
  canaryBasisPoints: 0,
  shadowEvaluationEnabled: false,
  internalAccountDigests: const {},
  rollbackCapabilities: rollback,
);
