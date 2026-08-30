import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final assistantReleaseConfigProvider = FutureProvider<AssistantReleaseConfig>((
  Ref ref,
) async {
  final intelligence = ref.watch(intelligenceStateProvider);
  final AssistantReleaseConfig config = await ref
      .read(featureFlagRepositoryProvider)
      .loadAssistantReleaseConfig();
  if (intelligence.flags.testerFullAccess &&
      !intelligence.environment.isProduction &&
      config.configurationValid) {
    return AssistantReleaseConfig(
      stage: AssistantReleaseStage.general,
      canaryBasisPoints: config.canaryBasisPoints,
      shadowEvaluationEnabled: config.shadowEvaluationEnabled,
      internalAccountDigests: config.internalAccountDigests,
      rollbackCapabilities: config.rollbackCapabilities,
    );
  }
  return config;
});

final assistantReleaseControllerProvider = Provider<AssistantReleaseController>(
  (Ref ref) => const AssistantReleaseController(),
);

final assistantBetaOptInProvider =
    AsyncNotifierProvider<AssistantBetaOptInNotifier, bool>(
      AssistantBetaOptInNotifier.new,
    );

final assistantReleaseDecisionProvider =
    FutureProvider.family<AssistantReleaseDecision, AssistantReleaseCapability>(
      (Ref ref, AssistantReleaseCapability capability) async {
        final AccountStorageScope scope = ref.watch(
          accountStorageScopeProvider,
        );
        final AssistantReleaseConfig config = await ref.watch(
          assistantReleaseConfigProvider.future,
        );
        final bool betaOptIn = await ref.watch(
          assistantBetaOptInProvider.future,
        );
        return ref
            .read(assistantReleaseControllerProvider)
            .decide(
              config: config,
              request: AssistantReleaseRequest(
                accountScopeId: scope.v2Namespace ?? 'v2.unsafe',
                capability: capability,
                betaOptIn: betaOptIn,
              ),
            );
      },
    );

/// Smart Planner can accept a request only when both its response path and
/// the safety critic are enabled for the current account cohort.
final smartPlannerAvailabilityProvider = FutureProvider<bool>((Ref ref) async {
  final AssistantReleaseDecision planner = await ref.watch(
    assistantReleaseDecisionProvider(
      AssistantReleaseCapability.smartPlannerV2,
    ).future,
  );
  final AssistantReleaseDecision safety = await ref.watch(
    assistantReleaseDecisionProvider(
      AssistantReleaseCapability.safetyCritic,
    ).future,
  );
  return planner.enabled && safety.enabled;
});

class AssistantBetaOptInNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    final String? key = _preferenceKey(scope);
    if (key == null) return false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    final String? key = _preferenceKey(scope);
    if (key == null) {
      throw StateError(
        'Assistant beta preference requires a verified account scope.',
      );
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool persisted = await prefs.setBool(key, enabled);
    if (!persisted) {
      throw StateError('Assistant beta preference could not be persisted.');
    }
    state = AsyncData<bool>(enabled);
  }

  String? _preferenceKey(AccountStorageScope scope) {
    final String? accountScopeId = scope.v2Namespace;
    if (!scope.isAuthenticated || accountScopeId == null) return null;
    final String digest = assistantReleaseAccountDigest(accountScopeId);
    return 'assistant_beta_opt_in_v1.$digest';
  }
}

Future<AssistantReleaseDecision> requireAssistantReleaseCapability(
  Ref ref,
  AssistantReleaseCapability capability,
) async {
  final AssistantReleaseDecision decision = await ref.read(
    assistantReleaseDecisionProvider(capability).future,
  );
  if (!decision.enabled) {
    throw AssistantReleaseBlockedException(decision);
  }
  return decision;
}
