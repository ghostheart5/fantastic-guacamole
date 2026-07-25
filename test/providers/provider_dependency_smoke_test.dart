import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Provider dependency smoke tests', () {
    test('critical providers build in same container', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(intelligenceStateProvider), returnsNormally);
      expect(() => container.read(appAccessProvider), returnsNormally);
      expect(() => container.read(energyProvider), returnsNormally);

      expect(
        () => container.read(sessionRecoveryProvider),
        returnsNormally,
      );

      expect(
        () => container.read(syncToCloudProvider),
        returnsNormally,
      );
    });

    test('providers survive repeated reads', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 25; i++) {
        container.read(intelligenceStateProvider);
        container.read(appAccessProvider);
        container.read(energyProvider);
      }
    });

    test('provider reads do not throw during combined access', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() {
        container.read(intelligenceStateProvider);
        container.read(appAccessProvider);
        container.read(energyProvider);
      }, returnsNormally);
    });
  });
}
