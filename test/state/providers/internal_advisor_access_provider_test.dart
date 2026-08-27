import 'dart:async';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internalAdvisorAccessProvider', () {
    test('grants access from trusted app metadata admin flag', () async {
      final ProviderContainer container = _containerFor(
        const User(
          id: 'admin-1',
          emailVerified: true,
          appMetadata: <String, dynamic>{'chronospark_admin': true},
        ),
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authUserProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(authUserProvider.future);
      expect(container.read(internalAdvisorAccessProvider), isTrue);
    });

    test('grants access from trusted app metadata role list', () async {
      final ProviderContainer container = _containerFor(
        const User(
          id: 'admin-2',
          emailVerified: true,
          appMetadata: <String, dynamic>{
            'chronospark_roles': <String>['member', 'product_admin'],
          },
        ),
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authUserProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(authUserProvider.future);
      expect(container.read(internalAdvisorAccessProvider), isTrue);
    });

    test('does not grant access without trusted app metadata', () async {
      final ProviderContainer container = _containerFor(
        const User(id: 'member-1', emailVerified: true),
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authUserProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(authUserProvider.future);
      expect(container.read(internalAdvisorAccessProvider), isFalse);
    });
  });
}

ProviderContainer _containerFor(User? user) {
  final StreamController<User?> controller = StreamController<User?>();
  controller.add(user);
  return ProviderContainer(
    overrides: [
      authUserProvider.overrideWith((Ref ref) {
        ref.onDispose(controller.close);
        return controller.stream;
      }),
    ],
  );
}
