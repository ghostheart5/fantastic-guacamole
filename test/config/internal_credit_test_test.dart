import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  const backend = 'https://test-project.supabase.co';
  const endpoint = '$backend/functions/v1/ai-proxy';
  test('credit and external AI availability follow cohort removal', () async {
    final membership = NotifierProvider<_Membership, bool>(_Membership.new);
    final container = ProviderContainer(
      overrides: [
        internalCreditTestEnabledProvider.overrideWith(
          (ref) => ref.watch(membership),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(externalAiAvailableProvider, (_, _) {});
    container.listen(creditSpendingAvailableProvider, (_, _) {});
    expect(container.read(externalAiAvailableProvider), isTrue);
    expect(container.read(creditSpendingAvailableProvider), isTrue);
    container.read(membership.notifier).revoke();
    await container.pump();
    expect(container.read(externalAiAvailableProvider), isFalse);
    expect(container.read(creditSpendingAvailableProvider), isFalse);
  });
  test('credit testing requires the verified billing cohort', () {
    expect(
      allowsInternalCreditTest(
        billingCohortAllowed: false,
        aiProxyEndpoint: endpoint,
        supabaseUrl: backend,
      ),
      isFalse,
    );
    expect(
      allowsInternalCreditTest(
        billingCohortAllowed: true,
        aiProxyEndpoint: endpoint,
        supabaseUrl: backend,
      ),
      isTrue,
    );
    expect(LaunchContainment.externalAiEnabled, isFalse);
    expect(LaunchContainment.creditSpendingEnabled, isFalse);
    expect(LaunchContainment.paidCreditPlansEnabled, isFalse);
  });
  for (final invalid in [
    '',
    'http://test-project.supabase.co/functions/v1/ai-proxy',
    'https://other-project.supabase.co/functions/v1/ai-proxy',
    '$endpoint?forward=elsewhere',
    '$endpoint#fragment',
    '$backend/functions/v1/other',
    'https://user@test-project.supabase.co/functions/v1/ai-proxy',
    'https://test-project.supabase.co:444/functions/v1/ai-proxy',
  ]) {
    test('credit testing rejects endpoint $invalid', () {
      expect(
        allowsInternalCreditTest(
          billingCohortAllowed: true,
          aiProxyEndpoint: invalid,
          supabaseUrl: backend,
        ),
        isFalse,
      );
    });
  }
}

class _Membership extends Notifier<bool> {
  @override
  bool build() => true;
  void revoke() => state = false;
}
