import 'package:fantastic_guacamole/tutorial/tutorial_asset_loader.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_overlay.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTutorialAssetLoader extends TutorialAssetLoader {
  const _FakeTutorialAssetLoader(this._definitions);

  final Map<String, TutorialDefinition> _definitions;

  @override
  Future<TutorialDefinition> load(String path) async {
    return _definitions[path] ??
        const TutorialDefinition(
          id: 'missing',
          title: 'missing',
          steps: <TutorialStep>[],
        );
  }

  @override
  Future<List<TutorialDefinition>> loadAll(List<String> paths) async {
    return Future.wait(paths.map(load));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapForTest(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(1920, 1080),
        textScaler: TextScaler.linear(0.70),
      ),
      child: child,
    );
  }

  TutorialDefinition twoStepDefinition() {
    return const TutorialDefinition(
      id: 'demo',
      title: 'Demo',
      steps: <TutorialStep>[
        TutorialStep(
          id: 'step-1',
          title: 'First Step',
          body: 'Tap the target to continue.',
          trigger: TutorialTriggerType.tap,
          targetId: 'target-1',
          nextStepId: 'step-2',
        ),
        TutorialStep(
          id: 'step-2',
          title: 'Second Step',
          body: 'Done',
          trigger: TutorialTriggerType.manual,
        ),
      ],
    );
  }

  group('TutorialOverlay widget behavior', () {
    testWidgets('overlay host builds with a TutorialController', (
      WidgetTester tester,
    ) async {
      final TutorialController controller = TutorialController(
        loader: _FakeTutorialAssetLoader(<String, TutorialDefinition>{
          'demo.json': twoStepDefinition(),
        }),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapForTest(
          MaterialApp(
            home: TutorialHost(
              controller: controller,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(TutorialHost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay does not throw when tutorial is inactive', (
      WidgetTester tester,
    ) async {
      final TutorialController controller = TutorialController(
        loader: const _FakeTutorialAssetLoader(<String, TutorialDefinition>{}),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapForTest(
          MaterialApp(
            home: TutorialHost(
              controller: controller,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.takeException(), isNull);
      expect(find.text('First Step'), findsNothing);
    });

    testWidgets('overlay advances from tap target event to next step', (
      WidgetTester tester,
    ) async {
      final TutorialController controller = TutorialController(
        loader: _FakeTutorialAssetLoader(<String, TutorialDefinition>{
          'demo.json': twoStepDefinition(),
        }),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapForTest(
          MaterialApp(
            home: TutorialHost(
              controller: controller,
              child: const Scaffold(
                body: Center(
                  child: TutorialTarget(
                    id: 'target-1',
                    child: SizedBox(width: 120, height: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await controller.loadAssets(const <String>['demo.json']);
      await controller.start('demo');
      await tester.pump(const Duration(milliseconds: 120));

      expect(controller.activeStep?.id, equals('step-1'));
      expect(find.text('First Step'), findsOneWidget);

      final Rect targetRect = tester.getRect(find.byType(TutorialTarget));
      await tester.tapAt(targetRect.center);
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.activeStep?.id, equals('step-2'));
      expect(find.text('Second Step'), findsOneWidget);
    });

    testWidgets('overlay handles missing target gracefully', (
      WidgetTester tester,
    ) async {
      final TutorialController controller = TutorialController(
        loader: _FakeTutorialAssetLoader(<String, TutorialDefinition>{
          'demo.json': twoStepDefinition(),
        }),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapForTest(
          MaterialApp(
            home: TutorialHost(
              controller: controller,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.byType(TutorialHost), findsOneWidget);
    });
  });
}
