import 'package:fantastic_guacamole/state/providers/first_run_tutorial_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FirstRunTutorialController', () {
    test('starts and advances through the guided steps', () async {
      final controller = FirstRunTutorialController();

      await controller.start();
      expect(controller.state.isActive, isTrue);
      expect(controller.state.currentStep, 0);

      await controller.next();
      expect(controller.state.currentStep, 1);

      await controller.next();
      expect(controller.state.currentStep, 2);

      await controller.next();
      expect(controller.state.completed, isTrue);
      expect(controller.state.isActive, isFalse);
    });

    test('skip completes the tutorial', () async {
      final controller = FirstRunTutorialController();

      await controller.start();
      await controller.skip();

      expect(controller.state.completed, isTrue);
      expect(controller.state.isActive, isFalse);
    });
  });
}
