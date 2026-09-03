import 'dart:async';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A verified, still-valid subscription as it would be persisted after a
/// successful purchase.
const SubscriptionState _activeSubscription = SubscriptionState(
  isActive: true,
  status: 'active',
  source: 'google_play',
  planId: 'monthly',
);

const SubscriptionState _inactiveSubscription = SubscriptionState(
  isActive: false,
  status: 'locked',
  source: 'google_play',
);

void main() {
  group('entitlement restores premium across launches', () {
    test('startup reads the backend authority refresher', () async {
      final _Harness harness = await _Harness.create(
        subscription: _inactiveSubscription,
        user: _user('user-a'),
      );

      await harness.container.read(entitlementProvider.future);

      expect(harness.repository.refreshCalls, 1);
    });

    test('legacy retry deadline rebuilds entitlement authority', () async {
      final _Harness harness = await _Harness.create(
        subscription: _inactiveSubscription,
        user: _user('user-a'),
        legacyRetryAt: DateTime.now().add(const Duration(milliseconds: 30)),
      );
      final int initialRefreshes = harness.repository.refreshCalls;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      await harness.settle();

      expect(harness.repository.refreshCalls, greaterThan(initialRefreshes));
    });

    test(
      'legacy subscription recovery runs once and claims the account',
      () async {
        final _Harness harness = await _Harness.create(
          subscription: _inactiveSubscription,
          user: _user('user-a'),
          legacyRestoreResult: _activeSubscription,
        );

        await harness.settle();

        expect(harness.repository.legacyRestoreCalls, 1);
        expect(
          (await harness.container.read(entitlementProvider.future)).isPremium,
          isTrue,
        );
        expect(await harness.readOwner(), 'user-a');

        harness.container.invalidate(entitlementProvider);
        await harness.settle();
        expect(harness.repository.legacyRestoreCalls, 1);
      },
    );

    test(
      'premium survives restart when the account owns the subscription',
      () async {
        final _Harness harness = await _Harness.create(
          subscription: _activeSubscription,
          owner: 'user-a',
          user: _user('user-a'),
        );

        final EntitlementState entitlement = await harness.container.read(
          entitlementProvider.future,
        );

        expect(entitlement.isPremium, isTrue);
        expect(
          harness.container.read(appAccessProvider).hasPremiumAccess,
          isTrue,
        );

        final AiCreditWallet wallet = await harness.container.read(
          aiCreditWalletProvider.future,
        );
        expect(wallet.tier, 'unavailable');
      },
    );

    test('free user stays free with no active subscription', () async {
      final _Harness harness = await _Harness.create(
        subscription: _inactiveSubscription,
        user: _user('user-a'),
      );

      final EntitlementState entitlement = await harness.container.read(
        entitlementProvider.future,
      );

      expect(entitlement.isPremium, isFalse);
      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isFalse,
      );

      final AiCreditWallet wallet = await harness.container.read(
        aiCreditWalletProvider.future,
      );
      expect(wallet.tier, 'unavailable');
    });

    test('expired subscription does not grant premium', () async {
      final _Harness harness = await _Harness.create(
        subscription: SubscriptionState(
          isActive: true,
          status: 'active',
          source: 'google_play',
          planId: 'monthly',
          renewalDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        owner: 'user-a',
        user: _user('user-a'),
      );

      final EntitlementState entitlement = await harness.container.read(
        entitlementProvider.future,
      );

      expect(entitlement.isPremium, isFalse);
      expect(entitlement.source, 'inactive');
      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isFalse,
      );
    });

    test('premium is revoked when the authoritative expiry passes', () async {
      final _Harness harness = await _Harness.create(
        subscription: SubscriptionState(
          isActive: true,
          status: 'active',
          source: 'google_play',
          planId: 'monthly',
          renewalDate: DateTime.now().add(const Duration(milliseconds: 500)),
        ),
        owner: 'user-a',
        user: _user('user-a'),
      );

      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );
      expect(
        (await harness.container.read(aiCreditWalletProvider.future)).tier,
        'unavailable',
      );

      await Future<void>.delayed(const Duration(milliseconds: 700));
      await harness.settle();

      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isFalse,
      );
      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isFalse,
      );
    });

    test('forced authority refresh invalidates revoked premium', () async {
      final _Harness harness = await _Harness.create(
        subscription: SubscriptionState(
          isActive: true,
          status: 'active',
          source: 'supabase_authority',
          planId: 'monthly',
          renewalDate: DateTime.now().add(const Duration(days: 1)),
        ),
        owner: 'user-a',
        user: _user('user-a'),
      );
      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );

      harness.repository.subscription = const SubscriptionState(
        isActive: false,
        status: 'revoked',
        source: 'supabase_authority',
      );
      await harness.container.read(entitlementAuthorityRefreshProvider)(
        force: true,
      );

      expect(harness.repository.refreshForces, contains(true));
      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isFalse,
      );
      expect(
        (await harness.container.read(aiCreditWalletProvider.future)).tier,
        'unavailable',
      );
      expect(await harness.readOwner(), isNull);
    });
  });

  group('entitlement is account safe', () {
    test('legacy owner marker is proven-owner read-only', () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await store.writeString(kEntitlementOwnerKey, 'user-a');
      final _Harness owner = await _Harness.create(
        subscription: _activeSubscription,
        user: _user('user-a'),
        secureStore: store,
        legacyOwnership: LegacyScopeOwnership.provenOwned,
      );

      expect(
        (await owner.container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );
      expect(await store.readString(kEntitlementOwnerKey), 'user-a');
      expect(
        await store
            .forAccount(AccountStorageScope.authenticated('user-a'))
            .readAll(),
        isEmpty,
      );

      final _Harness other = await _Harness.create(
        subscription: _activeSubscription,
        user: _user('user-b'),
        secureStore: store,
      );
      expect(
        (await other.container.read(entitlementProvider.future)).isPremium,
        isFalse,
      );
    });

    test(
      'a different account does not inherit premium on the same device',
      () async {
        // User A paid on this device; User B is now signed in.
        final _Harness harness = await _Harness.create(
          subscription: _activeSubscription,
          owner: 'user-a',
          user: _user('user-b'),
        );

        final EntitlementState entitlement = await harness.container.read(
          entitlementProvider.future,
        );

        expect(entitlement.isPremium, isFalse);
        expect(entitlement.source, 'unclaimed');
        expect(
          harness.container.read(appAccessProvider).hasPremiumAccess,
          isFalse,
        );
      },
    );

    test(
      'an unclaimed subscription is not granted to the signed-in account',
      () async {
        final _Harness harness = await _Harness.create(
          subscription: _activeSubscription,
          user: _user('user-a'),
        );

        final EntitlementState entitlement = await harness.container.read(
          entitlementProvider.future,
        );

        expect(entitlement.isPremium, isFalse);
        expect(entitlement.source, 'unclaimed');
      },
    );

    test(
      'sign-out clears premium access and the wallet recomputes as free',
      () async {
        final _Harness harness = await _Harness.create(
          subscription: _activeSubscription,
          owner: 'user-a',
          user: _user('user-a'),
        );

        expect(
          (await harness.container.read(entitlementProvider.future)).isPremium,
          isTrue,
        );
        expect(
          (await harness.container.read(aiCreditWalletProvider.future)).tier,
          'unavailable',
        );

        harness.signOut();
        await harness.settle();

        expect(
          (await harness.container.read(entitlementProvider.future)).isPremium,
          isFalse,
        );
        expect(
          harness.container.read(appAccessProvider).hasPremiumAccess,
          isFalse,
        );
        expect(
          (await harness.container.read(aiCreditWalletProvider.future)).tier,
          'unavailable',
        );
      },
    );
  });

  group('purchase and restore update access immediately', () {
    test('purchase grants premium and claims it for the account', () async {
      final _Harness harness = await _Harness.create(
        subscription: _inactiveSubscription,
        user: _user('user-a'),
      );
      await harness.container.read(entitlementProvider.future);
      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isFalse,
      );

      await harness.container
          .read(entitlementProvider.notifier)
          .applyPurchaseResult(_activeSubscription);

      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isTrue,
      );
      expect(await harness.readOwner(), 'user-a');
      expect(
        (await harness.container.read(aiCreditWalletProvider.future)).tier,
        'unavailable',
      );
    });

    test('restore grants premium and survives a subsequent launch', () async {
      final _Harness harness = await _Harness.create(
        subscription: _activeSubscription,
        user: _user('user-a'),
      );
      // Unclaimed on first launch.
      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isFalse,
      );

      await harness.container
          .read(entitlementProvider.notifier)
          .applyPurchaseResult(_activeSubscription);
      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isTrue,
      );

      // Relaunch against the same storage.
      final _Harness relaunched = await _Harness.create(
        subscription: _activeSubscription,
        user: _user('user-a'),
        secureStore: harness.secureStore,
      );
      expect(
        (await relaunched.container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );
    });

    test('cancellation drops the claim so premium is not re-granted', () async {
      final _Harness harness = await _Harness.create(
        subscription: _activeSubscription,
        owner: 'user-a',
        user: _user('user-a'),
      );
      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );

      await harness.container
          .read(entitlementProvider.notifier)
          .applyPurchaseResult(_inactiveSubscription);

      expect(
        harness.container.read(appAccessProvider).hasPremiumAccess,
        isFalse,
      );
      expect(await harness.readOwner(), isNull);
    });

    test('an account switch rejects an obsolete purchase result', () async {
      final _Harness harness = await _Harness.create(
        subscription: _inactiveSubscription,
        user: _user('user-a'),
      );
      await harness.container.read(entitlementProvider.future);

      harness.switchUser(_user('user-b'));
      await harness.settle();

      await expectLater(
        () => harness.container
            .read(entitlementProvider.notifier)
            .applyPurchaseResult(_activeSubscription, expectedUserId: 'user-a'),
        throwsStateError,
      );
      expect(await harness.readOwner(), isNull);
      expect(
        (await harness.container.read(entitlementProvider.future)).isPremium,
        isFalse,
      );
    });
  });
}

User _user(String id) {
  return User(
    id: id,
    email: '$id@example.com',
    displayName: id,
    emailVerified: true,
  );
}

class _Harness {
  _Harness({
    required this.container,
    required this.secureStore,
    required this.authController,
    required this.repository,
  });

  final ProviderContainer container;
  final SecureStore secureStore;
  final StreamController<User?> authController;
  final _FakePaywallRepository repository;
  static Future<_Harness> create({
    required SubscriptionState subscription,
    required User? user,
    String? owner,
    SecureStore? secureStore,
    SubscriptionState? legacyRestoreResult,
    DateTime? legacyRetryAt,
    LegacyScopeOwnership legacyOwnership = LegacyScopeOwnership.ambiguous,
  }) async {
    final SecureStore store =
        secureStore ?? SecureStore(backend: InMemorySecureStoreBackend());
    if (owner != null) {
      await store
          .forAccount(AccountStorageScope.authenticated(owner))
          .writeString(kEntitlementOwnerKey, owner);
    }

    // Not broadcast: the seeded value is buffered until Riverpod subscribes.
    final StreamController<User?> authController = StreamController<User?>();
    authController.add(user);

    final _FakePaywallRepository repository = _FakePaywallRepository(
      subscription: subscription,
      legacyRestoreResult: legacyRestoreResult,
      legacyRetryAt: legacyRetryAt,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        sharedPrefsStoreProvider.overrideWithValue(_InMemoryPrefsStore()),
        paywallRepositoryProvider.overrideWithValue(repository),
        authUserProvider.overrideWith((ref) => authController.stream),
        accountStorageScopeProvider.overrideWith((Ref ref) {
          final User? current = ref.watch(authUserProvider).asData?.value;
          return current == null
              ? const AccountStorageScope.signedOut()
              : AccountStorageScope.authenticated(current.id);
        }),
        accountLegacyOwnershipProvider.overrideWithValue(legacyOwnership),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authController.close);

    // `read` alone does not keep an async provider subscribed, so its stream is
    // never listened to and `.future` would never complete.
    container.listen(authUserProvider, (_, _) {}, fireImmediately: true);
    container.listen(entitlementProvider, (_, _) {}, fireImmediately: true);

    final _Harness harness = _Harness(
      container: container,
      secureStore: store,
      authController: authController,
      repository: repository,
    );
    await harness.settle();
    return harness;
  }

  void signOut() => authController.add(null);

  void switchUser(User user) => authController.add(user);

  Future<String?> readOwner([String userId = 'user-a']) {
    return secureStore
        .forAccount(AccountStorageScope.authenticated(userId))
        .readString(kEntitlementOwnerKey);
  }

  /// Lets a stream event propagate and the entitlement rebuild finish.
  Future<void> settle() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _InMemoryPrefsStore implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}

class _FakePaywallRepository
    implements IPaywallRepository, ISubscriptionAuthorityRefresher {
  _FakePaywallRepository({
    required this.subscription,
    this.legacyRestoreResult,
    this.legacyRetryAt,
  });

  SubscriptionState subscription;
  final SubscriptionState? legacyRestoreResult;
  final DateTime? legacyRetryAt;
  int refreshCalls = 0;
  final List<bool> refreshForces = <bool>[];
  int legacyRestoreCalls = 0;
  bool _legacyRestoreAvailable = true;

  @override
  Future<SubscriptionState> refreshSubscriptionState({
    bool force = false,
  }) async {
    refreshCalls += 1;
    refreshForces.add(force);
    return subscription;
  }

  @override
  bool get shouldRestoreLegacySubscription {
    return legacyRestoreResult != null && _legacyRestoreAvailable;
  }

  @override
  DateTime? get legacyRestoreNextRetryAt => legacyRetryAt;

  @override
  Future<SubscriptionState?> restoreLegacySubscription() async {
    if (!shouldRestoreLegacySubscription) {
      return null;
    }
    legacyRestoreCalls += 1;
    _legacyRestoreAvailable = false;
    subscription = legacyRestoreResult!;
    return subscription;
  }

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async => const <PaywallPlan>[];

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    return PaywallEntity(
      featureId: 'premium',
      title: 'Premium',
      body: 'Body',
      plans: const <PaywallPlan>[],
      isUnlocked: subscription.isActive,
    );
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async => subscription;

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    subscription = _activeSubscription;
    return subscription;
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    subscription = _activeSubscription;
    return subscription;
  }

  @override
  Future<SubscriptionState> cancelSubscription() async {
    subscription = _inactiveSubscription;
    return subscription;
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: subscription.isActive,
      source: subscription.source,
    );
  }
}
