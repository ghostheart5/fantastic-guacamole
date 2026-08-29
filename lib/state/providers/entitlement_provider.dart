import 'dart:async';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage key holding the account id that a verified subscription belongs to.
///
/// The subscription payload is account-scoped by the paywall repository. This
/// separate owner marker keeps entitlement attribution explicit for providers
/// that do not read repository persistence details.
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

typedef EntitlementAuthorityRefresh = Future<void> Function({bool force});

final entitlementAuthorityRefreshProvider =
    Provider<EntitlementAuthorityRefresh>((Ref ref) {
      return ({bool force = false}) async {
        final repository = ref.read(paywallRepositoryProvider);
        if (repository is ISubscriptionAuthorityRefresher) {
          await (repository as ISubscriptionAuthorityRefresher)
              .refreshSubscriptionState(force: force);
        }
        ref.invalidate(entitlementProvider);
        ref.invalidate(paywallSubscriptionProvider);
        ref.invalidate(paywallConfigProvider);
        ref.invalidate(aiCreditWalletProvider);
        await ref.read(entitlementProvider.future);
      };
    });

/// How often a foregrounded premium session rechecks server authority.
///
/// This is intentionally much shorter than the repository's offline lease:
/// the lease limits transient-failure access, while this interval bounds how
/// long an open app can retain access after an authoritative state change.
final entitlementAuthorityRecheckIntervalProvider = Provider<Duration>((
  Ref ref,
) {
  return const Duration(minutes: 1);
});

class EntitlementNotifier extends AsyncNotifier<EntitlementState> {
  Timer? _expiryTimer;
  static final Map<String, Future<void>> _ownerMutationQueues =
      <String, Future<void>>{};
  static final Map<String, int> _ownerMutationRevisions = <String, int>{};

  @override
  Future<EntitlementState> build() async {
    ref.onDispose(() => _expiryTimer?.cancel());
    // Rebuilds whenever the signed-in account changes, which is what resets
    // access on sign-out and on account switch.
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    final String? userId = scope.isWritable ? scope.rawUserId : null;
    if (userId == null) {
      _scheduleExpiry(null);
      return EntitlementState.locked;
    }

    final repository = ref.read(paywallRepositoryProvider);
    final ISubscriptionAuthorityRefresher? authorityRefresher =
        repository is ISubscriptionAuthorityRefresher
        ? repository as ISubscriptionAuthorityRefresher
        : null;
    final SubscriptionState subscription = authorityRefresher != null
        ? await authorityRefresher.refreshSubscriptionState()
        : await repository.getUserSubscriptionState();
    if (!ref.mounted || !_scopeStillMatches(userId)) {
      return EntitlementState.locked;
    }
    String? owner = await _readOwner(userId);
    if (!ref.mounted || !_scopeStillMatches(userId)) {
      return EntitlementState.locked;
    }
    if (subscription.source == 'supabase_authority') {
      if (_isActive(subscription)) {
        await _writeOwner(userId);
        owner = userId;
      } else if (owner == userId) {
        await _clearOwner(userId);
        owner = null;
      }
    }
    if (authorityRefresher?.shouldRestoreLegacySubscription ?? false) {
      unawaited(_recoverLegacySubscription(authorityRefresher!, userId));
    }
    _scheduleExpiry(
      subscription,
      legacyRetryAt: authorityRefresher?.legacyRestoreNextRetryAt,
    );
    return _resolve(userId: userId, subscription: subscription, owner: owner);
  }

  /// Applies a purchase or restore result to the single entitlement owner.
  ///
  /// Claiming the subscription for the signed-in account here is what makes it
  /// survive the next launch: [build] refuses to grant premium for a
  /// subscription it cannot attribute to the current user.
  Future<void> applyPurchaseResult(
    SubscriptionState subscription, {
    String? expectedUserId,
  }) async {
    final User? user = await ref.read(authUserProvider.future);
    final String? userId = user?.id;
    if (expectedUserId != null && userId != expectedUserId) {
      throw StateError('The signed-in account changed during billing.');
    }
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
      _scheduleExpiry(subscription);
      return;
    }

    if (active && !subscription.isTesting) {
      await _writeOwner(userId);
    } else if (!active) {
      // Cancelled or failed: drop the claim so it cannot be re-granted later.
      await _clearOwner(userId);
    }

    state = AsyncData(
      _resolve(
        userId: userId,
        subscription: subscription,
        // The claim was just written, so this account owns the subscription.
        owner: userId,
      ),
    );
    _scheduleExpiry(subscription);
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

  void _scheduleExpiry(
    SubscriptionState? subscription, {
    DateTime? legacyRetryAt,
  }) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final DateTime now = DateTime.now();
    final List<DateTime> deadlines = <DateTime>[];
    if (subscription != null && _isActive(subscription)) {
      final DateTime? expiry = subscription.renewalDate;
      if (expiry != null && expiry.isAfter(now)) {
        deadlines.add(expiry);
      }
    }
    if (legacyRetryAt != null && legacyRetryAt.isAfter(now)) {
      deadlines.add(legacyRetryAt);
    }
    if (deadlines.isEmpty) {
      return;
    }
    deadlines.sort();
    _expiryTimer = Timer(deadlines.first.difference(now), ref.invalidateSelf);
  }

  Future<void> _recoverLegacySubscription(
    ISubscriptionAuthorityRefresher repository,
    String expectedUserId,
  ) async {
    final SubscriptionState? restored = await repository
        .restoreLegacySubscription();
    if (restored == null) {
      if (ref.mounted) {
        ref.invalidateSelf();
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    final User? currentUser = await ref.read(authUserProvider.future);
    if (!ref.mounted || currentUser?.id != expectedUserId) {
      return;
    }
    await applyPurchaseResult(restored, expectedUserId: expectedUserId);
    ref.invalidate(paywallSubscriptionProvider);
    ref.invalidate(paywallConfigProvider);
    ref.invalidate(aiCreditWalletProvider);
  }

  bool _scopeStillMatches(String userId) {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    return scope.isWritable && scope.rawUserId == userId;
  }

  String _ownerKey(String userId) => '$kEntitlementOwnerKey.account.$userId';

  Future<String?> _readOwner(String userId) async {
    try {
      final store = ref.read(secureStoreProvider);
      String? owner = await store.readString(_ownerKey(userId));
      if ((owner?.trim().isEmpty ?? true)) {
        final String? legacyOwner = await store.readString(
          kEntitlementOwnerKey,
        );
        if (legacyOwner?.trim() == userId) {
          await _queueOwnerMutation(userId, owner: userId);
          await store.delete(kEntitlementOwnerKey);
          owner = userId;
        }
      }
      final String trimmed = owner?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      // Unreadable storage must not grant access.
      return null;
    }
  }

  Future<void> _writeOwner(String userId) async {
    await _queueOwnerMutation(userId, owner: userId);
  }

  Future<void> _clearOwner(String userId) async {
    await _queueOwnerMutation(userId);
  }

  Future<void> _queueOwnerMutation(String userId, {String? owner}) async {
    final String key = _ownerKey(userId);
    final int revision = (_ownerMutationRevisions[key] ?? 0) + 1;
    _ownerMutationRevisions[key] = revision;
    final Future<void> previous =
        _ownerMutationQueues[key] ?? Future<void>.value();
    late final Future<void> queued;
    queued = previous.catchError((Object _) {}).then((_) async {
      if (_ownerMutationRevisions[key] != revision) {
        return;
      }
      final store = ref.read(secureStoreProvider);
      if (owner == null) {
        await store.delete(key);
      } else {
        await store.writeString(key, owner);
      }
    });
    _ownerMutationQueues[key] = queued;
    try {
      await queued;
    } on Object {
      // Storage failures fail closed and must not fail a completed purchase.
    } finally {
      if (identical(_ownerMutationQueues[key], queued)) {
        _ownerMutationQueues.remove(key);
        _ownerMutationRevisions.remove(key);
      }
    }
  }
}
