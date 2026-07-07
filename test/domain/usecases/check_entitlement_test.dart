import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/check_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CheckEntitlement forwards featureId and returns repository entitlement', () async {
    final _FakePaywallRepository repository = _FakePaywallRepository();

    final Entitlement entitlement = await CheckEntitlement(
      repository,
    ).call(featureId: 'si_console');

    expect(repository.lastFeatureId, 'si_console');
    expect(entitlement.featureId, 'si_console');
    expect(entitlement.isEntitled, isTrue);
  });
}

class _FakePaywallRepository implements IPaywallRepository {
  String? lastFeatureId;

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    lastFeatureId = featureId;
    return Entitlement(featureId: featureId ?? 'premium', isEntitled: true, source: 'test');
  }

  @override
  Future<SubscriptionState> cancelSubscription() {
    throw UnimplementedError();
  }

  @override
  Future<List<PaywallPlan>> getAvailablePlans() {
    throw UnimplementedError();
  }

  @override
  Future<PaywallEntity> getPaywallConfig() {
    throw UnimplementedError();
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() {
    throw UnimplementedError();
  }

  @override
  Future<SubscriptionState> restorePurchases() {
    throw UnimplementedError();
  }

  @override
  Future<SubscriptionState> startSubscription(String planId) {
    throw UnimplementedError();
  }
}
