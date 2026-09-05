// CHRONOSPARK-CLASS: SHIPPING | Feature: Optional Planner explanation
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/ai/planner_explanation_service.dart';
import 'package:fantastic_guacamole/domain/entities/planner_explanation_contract.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum PlannerExplanationAvailability {
  launchContained,
  providerRetentionUnverified,
  safetyReviewRequired,
  personalizationConsentRequired,
  endpointUnavailable,
  authenticationRequired,
  releaseBlocked,
  available,
}

final plannerExplanationAvailabilityProvider =
    FutureProvider<PlannerExplanationAvailability>((Ref ref) async {
      if (!Env.externalAiEnabled || !Env.creditSpendingEnabled) {
        return PlannerExplanationAvailability.launchContained;
      }
      if (!LaunchContainment.externalAiProviderRetentionVerified) {
        return PlannerExplanationAvailability.providerRetentionUnverified;
      }
      if (!LaunchContainment.externalAiSafetyReviewApproved) {
        return PlannerExplanationAvailability.safetyReviewRequired;
      }
      if (!ref.watch(personalizationProfileProvider).externalAiAllowed) {
        return PlannerExplanationAvailability.personalizationConsentRequired;
      }
      final String endpoint = Env.plannerExplanationEndpoint.trim();
      if (endpoint.isEmpty) {
        return PlannerExplanationAvailability.endpointUnavailable;
      }
      final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
      if (client?.auth.currentSession == null) {
        return PlannerExplanationAvailability.authenticationRequired;
      }
      final AssistantReleaseDecision release = await ref.watch(
        assistantReleaseDecisionProvider(
          AssistantReleaseCapability.plannerExplanation,
        ).future,
      );
      return release.enabled
          ? PlannerExplanationAvailability.available
          : PlannerExplanationAvailability.releaseBlocked;
    });

final plannerExplanationHttpClientProvider = Provider<http.Client>((Ref ref) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final plannerExplanationPortProvider = FutureProvider<PlannerExplanationPort>((
  Ref ref,
) async {
  final PlannerExplanationAvailability availability = await ref.watch(
    plannerExplanationAvailabilityProvider.future,
  );
  if (availability != PlannerExplanationAvailability.available) {
    return const DisabledPlannerExplanationPort();
  }
  final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
  final Uri? endpoint = Uri.tryParse(Env.plannerExplanationEndpoint);
  if (client == null ||
      client.auth.currentSession == null ||
      endpoint == null) {
    return const DisabledPlannerExplanationPort();
  }
  return HttpPlannerExplanationService(
    endpoint: endpoint,
    apiKey: Env.supabaseAnonKey,
    accessToken: () async => client.auth.currentSession?.accessToken,
    client: ref.watch(plannerExplanationHttpClientProvider),
  );
});
