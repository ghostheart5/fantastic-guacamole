import 'dart:async';

import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('disposeAsync waits for purchase-stream cancellation', () async {
    final Completer<void> cancellationStarted = Completer<void>();
    final Completer<void> allowCancellation = Completer<void>();
    final StreamController<List<PurchaseDetails>> purchases =
        StreamController<List<PurchaseDetails>>(
          onCancel: () {
            cancellationStarted.complete();
            return allowCancellation.future;
          },
        );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _DisposalBillingClient(purchases.stream),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    bool disposalCompleted = false;
    final Future<void> disposal = repository.disposeAsync().then((_) {
      disposalCompleted = true;
    });

    await cancellationStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(disposalCompleted, isFalse);

    allowCancellation.complete();
    await disposal;
    expect(disposalCompleted, isTrue);
    await purchases.close();
  });

  test('disposeAsync exposes purchase-stream cancellation failures', () async {
    final StreamController<List<PurchaseDetails>> purchases =
        StreamController<List<PurchaseDetails>>(
          onCancel: () => Future<void>.error(StateError('cancel failed')),
        );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _DisposalBillingClient(purchases.stream),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    await expectLater(repository.disposeAsync(), throwsA(isA<StateError>()));
    await purchases.close();
  });
}

final class _DisposalBillingClient implements BillingClient {
  const _DisposalBillingClient(this.purchaseStream);

  @override
  final Stream<List<PurchaseDetails>> purchaseStream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    throw UnsupportedError('Purchases are not used by disposal tests.');
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    throw UnsupportedError('Purchases are not used by disposal tests.');
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    throw UnsupportedError('Products are not used by disposal tests.');
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    throw UnsupportedError('Restore is not used by disposal tests.');
  }
}
