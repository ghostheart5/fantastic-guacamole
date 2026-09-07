import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/subscription_status_refresh_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('billing surfaces refresh on entry, foreground and Play return', (
    tester,
  ) async {
    int refreshes = 0;
    final container = ProviderContainer(
      overrides: [
        subscriptionPurchasingEnabledProvider.overrideWithValue(true),
        entitlementAuthorityRecheckIntervalProvider.overrideWithValue(
          const Duration(seconds: 1),
        ),
        entitlementAuthorityRefreshProvider.overrideWithValue(({
          bool force = false,
        }) async {
          expect(force, isTrue);
          refreshes++;
        }),
      ],
    );
    addTearDown(container.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            ref.watch(subscriptionStatusRefreshProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(refreshes, 1);
    // No premium gate: inactive accounts must also discover external resumption.
    await tester.pump(const Duration(seconds: 1));
    expect(refreshes, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(refreshes, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshes, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(refreshes, 3, reason: 'Disposed screens must stop polling.');
  });
}
