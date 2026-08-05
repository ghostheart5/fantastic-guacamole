import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage key holding the account id that a verified subscription belongs to.
///
/// The subscription payload itself is written by the paywall repository under a
/// device-global key. Recording the owning account separately is what stops a
/// second user on the same device from inheriting the first user's premium.
const String kEntitlementOwnerKey = 'entitlement_owner_user_id_v1';

/// Resolved premium access for the currently authenticated account.
class EntitlementState {
  const EntitlementState({
    required this.isPremium,
    this.userId,
    this.source = 'locked',
  });

  final bool isPremium;
  final String? userId;

  /// Why access resolved the way it did. Diagnostic only; never a gate.
  final String source;

  static const EntitlementState locked = EntitlementState(isPremium: false);

  @override
  bool operator ==(Object other) {
    return other is EntitlementState &&
        other.isPremium == isPremium &&
        other.userId == userId &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(isPremium, userId, source);
}

/// The single owner of premium truth.
///
/// Premium is derived from the persisted, server-verified [SubscriptionState]
/// and the account that paid for it. Before this provider existed the only
/// source was a session-scoped flag set by the paywall page, so a paying user
/// relaunched as a free user until they manually tapped Restore.
///
/// Deliberately async: the persisted subscription is read from storage, so
/// callers that must not act on a premature answer can await
/// `entitlementProvider.future`. Synchronous readers see "not premium" until it
/// resolves, which fails closed.
final entitlementProvider =
    AsyncNotifierProvider<EntitlementNotifier, EntitlementState>(
      EntitlementNotifier.new,
    );

class EntitlementNotifier extends AsyncNotifier<EntitlementState> {
  @override
  Future<EntitlementState> build() async {
    // Rebuilds whenever the signed-in account changes, which is what resets
    // access on sign-out and on account switch.
    final User? user = await ref.watch(authUserProvider.future);
    final String? userId = user?.id;
    if (userId == null) {
      return EntitlementState.locked;
    }

    final SubscriptionState subscription = await ref
        .read(paywallRepositoryProvider)
        .getUserSubscriptionState();
    final String? owner = await _readOwner();
    return _resolve(
      userId: userId,
      subscription: subscription,
      owner: owner,
    );
  }

  /// Applies a purchase or restore result to the single entitlement owner.
  ///
  /// Claiming the subscription for the signed-in account here is what makes it
  /// survive the next launch: [build] refuses to grant premium for a
  /// subscription it cannot attribute to the current user.
  Future<void> applyPurchaseResult(SubscriptionState subscription) async {
    final User? user = await ref.read(authUserProvider.future);
    final String? userId = user?.id;
    final bool active = _isActive(subscription);

    if (userId == null) {
      // No account to attribute the purchase to (non-production flows only;
      // production receipt verification requires an authenticated session).
      state = AsyncData(
        EntitlementState(
          isPremium: active,
          source: active ? 'session' : 'inactive',
        ),
      );
      return;
    }

    if (active && !subscription.isTesting) {
      await _writeOwner(userId);
    } else if (!active) {
      // Cancelled or failed: drop the claim so it cannot be re-granted later.
      await _clearOwner();
    }

    state = AsyncData(
      _resolve(
        userId: userId,
        subscription: subscription,
        // The claim was just written, so this account owns the subscription.
        owner: userId,
      ),
    );
  }

  EntitlementState _resolve({
    required String userId,
    required SubscriptionState subscription,
    required String? owner,
  }) {
    if (!_isActive(subscription)) {
      return EntitlementState(
        isPremium: false,
        userId: userId,
        source: 'inactive',
      );
    }
    if (subscription.isTesting) {
      // QA/testing repositories self-report an unlocked state and are not tied
      // to a paying account.
      return EntitlementState(
        isPremium: true,
        userId: userId,
        source: 'testing_mode',
      );
    }
    if (owner == null) {
      // An active subscription with no recorded owner cannot be attributed to
      // this account. Fail closed; Restore re-claims it for the signed-in user.
      return EntitlementState(
        isPremium: false,
        userId: userId,
        source: 'unclaimed',
      );
    }
    if (owner != userId) {
      // The subscription belongs to a different account on this device.
      return EntitlementState(
        isPremium: false,
        userId: userId,
        source: 'other_account',
      );
    }
    return EntitlementState(
      isPremium: true,
      userId: userId,
      source: subscription.source,
    );
  }

  /// Re-checks local validity so an expired subscription cannot be granted even
  /// if the persisted flag still says active.
  bool _isActive(SubscriptionState subscription) {
    if (!subscription.isActive) {
      return false;
    }
    final DateTime? renewal = subscription.renewalDate;
    return renewal == null || renewal.isAfter(DateTime.now());
  }

  Future<String?> _readOwner() async {
    try {
      final String? owner = await ref
          .read(secureStoreProvider)
          .readString(kEntitlementOwnerKey);
      final String trimmed = owner?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      // Unreadable storage must not grant access.
      return null;
    }
  }

  Future<void> _writeOwner(String userId) async {
    try {
      await ref.read(secureStoreProvider).writeString(
        kEntitlementOwnerKey,
        userId,
      );
    } on Object {
      // Never fail a completed purchase because the claim could not be stored.
    }
  }

  Future<void> _clearOwner() async {
    try {
      await ref.read(secureStoreProvider).delete(kEntitlementOwnerKey);
    } on Object {
      // Ignore storage failures; access still resolves from subscription state.
    }
  }
}
