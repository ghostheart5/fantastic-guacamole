import 'dart:async';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/state/core/state_bootstrap.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_lifecycle_provider.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionLifecycleIntegrationFixture {
  AuthSessionLifecycleIntegrationFixture({SecureStore? store})
      : auth = FixtureAuthService(),
        store = store ?? SecureStore(backend: InMemorySecureStoreBackend()),
        _observer = _LifecycleEvents();

  final FixtureAuthService auth;
  final SecureStore store;
  final _LifecycleEvents _observer;
  final List<String> notificationPlatformCalls = <String>[];
  List<String> get events => _observer.values;

  Future<ProviderContainer> createContainer({String ownerId = 'lifecycle-owner-a'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationsChannel, (MethodCall call) async {
      notificationPlatformCalls.add(call.method);
      if (call.method == 'initialize') return true;
      return null;
    });
    if (await store.readString(_ownershipKey) == null) {
      await store.writeString(_ownershipKey, 'user:$ownerId');
    }
    return ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          secureStoreProvider.overrideWithValue(store),
          authSessionLifecycleObserverProvider.overrideWithValue(_observer),
          purchaseRepositoryProvider.overrideWithValue(_FixturePurchaseRepository()),
          notificationSchedulerProvider.overrideWithValue(
            NotificationScheduler.withAccountRemovalCancelAll(() async {
              notificationPlatformCalls.add('cancelAll');
            }),
          ),
          stateBootstrapProvider.overrideWith((Ref ref) async {}),
        ],
      );
  }

  User user(String id) => User(id: id, email: '$id@example.com', emailVerified: true);

  Future<String?> readOwnerMarker() => store.readString(_ownershipKey);
}

const String _ownershipKey = 'chronospark.local_session_owner.v1';

const MethodChannel _notificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

class _FixturePurchaseRepository implements PurchaseRepository {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream<List<PurchaseDetails>>.empty();
  @override
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) => throw UnsupportedError('not used by lifecycle fixture');
  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) => throw UnsupportedError('not used by lifecycle fixture');
  @override
  Future<PurchaseResult> restorePurchases() => throw UnsupportedError('not used by lifecycle fixture');
}

class _LifecycleEvents implements AuthSessionLifecycleObserver {
  final List<String> values = <String>[];
  @override
  void onEvent(String event) => values.add(event);
}

class FixtureAuthService implements AuthServiceContract {
  User? user;
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
  @override
  Future<void> deleteCurrentAccount({required String password}) => throw UnimplementedError();
  @override
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({bool forceRefresh = false}) async => null;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;
  @override
  Future<User?> reloadCurrentUser() async => user;
  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();
  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();
  @override
  Future<void> sendPhoneOtp(String phone) => throw UnimplementedError();
  @override
  Future<UserCredential> signIn({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> signOut() async => user = null;
  @override
  Future<UserCredential> signUp({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<void> updatePassword({required String newPassword}) => throw UnimplementedError();
  @override
  Future<UserCredential> verifyPhoneOtp({required String phone, required String token}) => throw UnimplementedError();
}
