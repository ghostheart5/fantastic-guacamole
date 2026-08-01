import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_compat_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Reusable app-level integration actions.
///
/// This service centralizes cross-connector actions so callers avoid coupling
/// to multiple provider trees for auth, monetization, sync, health, and bridge
/// operations.
class AppIntegrationActions {
  const AppIntegrationActions(this._ref);

  final Ref _ref;

  Future<AppIntegrationSnapshot> fetchIntegrationSnapshot() async {
    final MonetizationStatusSnapshot monetizationStatus =
        await fetchMonetizationSnapshot();
    final SupabaseBackendHealth supabaseHealth = await checkSupabaseHealth();
    final String? syncErrorMessage = _ref.read(syncErrorMessageProvider);
    final int offlineQueueCount = _ref
        .read(offlineQueueCountProvider)
        .maybeWhen(data: (int value) => value, orElse: () => 0);
    final String? currentUserId = currentUser?.id;

    return AppIntegrationSnapshot(
      currentUserId: currentUserId,
      supabaseHealth: supabaseHealth,
      syncErrorMessage: syncErrorMessage,
      offlineQueueCount: offlineQueueCount,
      monetizationStatus: monetizationStatus,
    );
  }

  Future<SupabaseBackendHealth> checkSupabaseHealth() {
    return _ref.read(supabaseBackendHealthProvider.future);
  }

  Future<bool> syncToCloud() async {
    final syncService = _ref.read(syncServiceProvider);
    if (syncService == null) {
      return false;
    }
    return syncService.syncToCloud();
  }

  Future<bool> syncDelta() async {
    final syncService = _ref.read(syncServiceProvider);
    if (syncService == null) {
      return false;
    }
    return syncService.syncDelta();
  }

  Future<bool> restoreFromCloud() async {
    final syncService = _ref.read(syncServiceProvider);
    if (syncService == null) {
      return false;
    }
    return syncService.restoreFromCloud();
  }

  Future<void> signOut() {
    return _ref.read(authServiceProvider).signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _ref.read(authServiceProvider).sendPasswordReset(email);
  }

  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() {
    return _ref.read(monetizationConnectorActionsProvider).fetchPlans();
  }

  Future<UserSubscription?> fetchCurrentSubscription() {
    return _ref
        .read(monetizationConnectorActionsProvider)
        .fetchSubscriptionStatus();
  }

  Future<PremiumEntitlement> fetchPremiumEntitlement() {
    return _ref
        .read(monetizationConnectorActionsProvider)
        .fetchPremiumEntitlement();
  }

  Future<MonetizationStatusSnapshot> fetchMonetizationSnapshot() {
    return _ref.read(monetizationActionsCompatProvider).fetchStatus();
  }

  Future<List<MonetizationPlanOption>> fetchMonetizationPlanOptions() {
    return _ref.read(monetizationActionsCompatProvider).fetchPlanOptions();
  }

  Future<List<MonetizationCreditOption>> fetchMonetizationCreditOptions() {
    return _ref.read(monetizationActionsCompatProvider).fetchCreditOptions();
  }

  MonetizationStackType get monetizationStackType {
    return _ref.read(monetizationActionsCompatProvider).stackType;
  }

  Future<AiCreditWallet?> fetchWallet() {
    return _ref.read(monetizationConnectorActionsProvider).fetchWallet();
  }

  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) {
    return _ref
        .read(monetizationConnectorActionsProvider)
        .purchaseSubscription(plan);
  }

  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) {
    return _ref
        .read(monetizationConnectorActionsProvider)
        .purchaseCredits(pack);
  }

  Future<PurchaseResult> restorePurchases() {
    return _ref.read(monetizationConnectorActionsProvider).restorePurchases();
  }

  Future<bool> syncFirebaseMessagingToken({String source = 'manual'}) async {
    final sb.SupabaseClient? client = _ref.read(supabaseClientProvider);
    final String? token = FirebaseMessagingBootstrap.latestToken;
    if (client == null || token == null || token.trim().isEmpty) {
      return false;
    }
    await _ref
        .read(firebaseSupabaseBridgeRepositoryProvider)
        .syncFirebaseMessagingToken(client, token, source: source);
    return true;
  }

  User? get currentUser => _ref.read(authServiceProvider).currentUser;
}

class AppIntegrationSnapshot {
  const AppIntegrationSnapshot({
    required this.currentUserId,
    required this.supabaseHealth,
    required this.syncErrorMessage,
    required this.offlineQueueCount,
    required this.monetizationStatus,
  });

  final String? currentUserId;
  final SupabaseBackendHealth supabaseHealth;
  final String? syncErrorMessage;
  final int offlineQueueCount;
  final MonetizationStatusSnapshot monetizationStatus;
}
