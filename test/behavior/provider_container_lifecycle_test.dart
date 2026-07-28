import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_reset_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderContainer lifecycle', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
    });

    test('tutorial providers can be read and container disposes safely', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(tutorialRepositoryProvider);
      final analytics = container.read(tutorialAnalyticsProvider);
      final controller = container.read(tutorialControllerProvider);
      final resetService = container.read(tutorialResetServiceProvider);
      final progress = await container.read(tutorialProgressProvider.future);

      expect(repository, isNotNull);
      expect(analytics, isNotNull);
      expect(controller, isNotNull);
      expect(resetService, isNotNull);
      expect(progress.contentVersion, greaterThan(0));

      expect(() => container.dispose(), returnsNormally);
    });
  });
}
