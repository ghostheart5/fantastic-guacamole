import 'package:fantastic_guacamole/tutorial/tutorial_asset_loader.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `resume()`/`restart()`/`updateInput()` were removed as confirmed dead code
/// (zero callers anywhere in lib/) as part of L-09. This covers the engine
/// paths that remain reachable through the app's one live entry point
/// (`home_onboarding`, started from Settings).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialController', () {
    late TutorialController controller;

    setUp(() {
      controller = TutorialController(
        loader: const _FakeTutorialAssetLoader(<TutorialDefinition>[
          TutorialDefinition(
            id: 'home_onboarding',
            title: 'Home Onboarding',
            steps: <TutorialStep>[
              TutorialStep(
                id: 'step-1',
                title: 'Step 1',
                body: 'First step',
                trigger: TutorialTriggerType.tap,
                targetId: 'target-1',
              ),
              TutorialStep(
                id: 'step-2',
                title: 'Step 2',
                body: 'Second step',
                trigger: TutorialTriggerType.state,
                stateKey: 'flag',
                stateValue: true,
                // step-branch sits between step-2 and step-3 in this list (so
                // it can also be reached via the branch below); without this,
                // the no-branch-match fallback walks the array by index and
                // lands on step-branch instead of the intended step-3.
                nextStepId: 'step-3',
                branches: <TutorialBranch>[
                  TutorialBranch(
                    whenKey: 'variant',
                    equalsValue: 'b',
                    gotoStepId: 'step-branch',
                  ),
                ],
              ),
              TutorialStep(
                id: 'step-branch',
                title: 'Branch Step',
                body: 'Reached via branch',
                trigger: TutorialTriggerType.manual,
              ),
              TutorialStep(
                id: 'step-3',
                title: 'Step 3',
                body: 'Final step',
                trigger: TutorialTriggerType.manual,
              ),
            ],
          ),
        ]),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('start begins at the tutorial\'s first step', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      expect(controller.running, isTrue);
      expect(controller.activeStep?.id, 'step-1');
    });

    test('reportEvent matching the active tap trigger advances to next step', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      controller.reportEvent('tap:target-1');
      await Future<void>.value();

      expect(controller.activeStep?.id, 'step-2');
    });

    test('a branch is taken when its condition matches', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      controller.reportEvent('tap:target-1');
      await Future<void>.value();
      expect(controller.activeStep?.id, 'step-2');

      controller.updateState('variant', 'b');
      controller.updateState('flag', true);
      await Future<void>.value();

      expect(controller.activeStep?.id, 'step-branch');
    });

    test('no matching branch falls through to the linear next step', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      controller.reportEvent('tap:target-1');
      await Future<void>.value();
      expect(controller.activeStep?.id, 'step-2');

      controller.updateState('flag', true);
      await Future<void>.value();

      expect(controller.activeStep?.id, 'step-3');
    });

    test('skip marks the tutorial complete and stops it', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      await controller.skip();

      expect(controller.running, isFalse);
      expect(controller.activeStep, isNull);

      // Completed tutorials don't restart without an explicit restart flag.
      await controller.start('home_onboarding');
      expect(controller.running, isFalse);
    });

    test('advancing past the last step finishes the tutorial', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');

      controller.reportEvent('tap:target-1');
      await Future<void>.value();
      controller.updateState('flag', true);
      await Future<void>.value();
      expect(controller.activeStep?.id, 'step-3');

      await controller.next();

      expect(controller.running, isFalse);
      expect(controller.activeStep, isNull);
    });

    test('pause stops further auto-progression until the step is re-triggered', () async {
      await controller.loadAssets(<String>['ignored']);
      await controller.start('home_onboarding');
      expect(controller.activeStep?.id, 'step-1');

      await controller.pause();
      expect(controller.paused, isTrue);

      controller.reportEvent('tap:target-1');
      await Future<void>.value();

      expect(
        controller.activeStep?.id,
        'step-1',
        reason: 'a paused controller must not advance on a matching trigger',
      );
    });
  });
}

class _FakeTutorialAssetLoader extends TutorialAssetLoader {
  const _FakeTutorialAssetLoader(this.definitions);

  final List<TutorialDefinition> definitions;

  @override
  Future<List<TutorialDefinition>> loadAll(List<String> paths) async =>
      definitions;
}
