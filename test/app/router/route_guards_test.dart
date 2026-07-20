import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premiumAccessGuardProvider blocks locked premium access', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appAccessProvider.overrideWith(
          (Ref ref) => const AppAccessState(
            hasPremiumAccess: false,
            hasTesterFullAccess: false,
            paywallDisabled: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(premiumAccessGuardProvider), isFalse);
  });

  test('premiumAccessGuardProvider allows premium users', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appAccessProvider.overrideWith(
          (Ref ref) => const AppAccessState(
            hasPremiumAccess: true,
            hasTesterFullAccess: false,
            paywallDisabled: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(premiumAccessGuardProvider), isTrue);
  });
}
