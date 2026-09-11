import 'dart:async';

import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/core/state_bootstrap.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Learning extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _PendingEntitlement extends EntitlementNotifier {
  _PendingEntitlement(this.response);
  final Future<EntitlementState> response;

  @override
  Future<EntitlementState> build() => response;
}

void main() {
  test(
    'local startup completes while remote authority remains pending',
    () async {
      final response = Completer<EntitlementState>();
      final container = ProviderContainer(
        overrides: [
          learningProvider.overrideWith(_Learning.new),
          entitlementProvider.overrideWith(
            () => _PendingEntitlement(response.future),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(stateBootstrapProvider.future)
          .timeout(const Duration(seconds: 1));
      expect(container.read(latestSiSnapshotProvider), isNotNull);
      expect(container.read(entitlementProvider).isLoading, isTrue);
      expect(
        container.read(entitlementProvider).value?.isPremium ?? false,
        isFalse,
      );

      response.complete(
        const EntitlementState(
          isPremium: true,
          userId: 'verified-owner',
          source: 'fixture-authority',
        ),
      );
      expect(
        (await container.read(entitlementProvider.future)).isPremium,
        isTrue,
      );
    },
  );

  test(
    'authority failure stays in its provider without failing local startup',
    () async {
      final response = Completer<EntitlementState>();
      final container = ProviderContainer(
        overrides: [
          learningProvider.overrideWith(_Learning.new),
          entitlementProvider.overrideWith(
            () => _PendingEntitlement(response.future),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(stateBootstrapProvider.future)
          .timeout(const Duration(seconds: 1));
      final failure = expectLater(
        container.read(entitlementProvider.future),
        throwsStateError,
      );
      response.completeError(StateError('authority unavailable'));
      await failure;
      expect(container.read(entitlementProvider).hasError, isTrue);
      expect(
        container.read(entitlementProvider).value?.isPremium ?? false,
        isFalse,
      );
      expect(container.read(latestSiSnapshotProvider), isNotNull);
      expect(container.read(stateBootstrapProvider).hasError, isFalse);
    },
  );
}
