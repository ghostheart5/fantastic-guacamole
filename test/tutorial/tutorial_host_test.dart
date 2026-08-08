import 'package:fantastic_guacamole/tutorial/tutorial_asset_loader.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// TutorialHost is the one place the JSON-driven walkthrough engine actually
/// renders anything (mounted app-wide by AppRoot). This covers the surface
/// that "Start Tutorial" in Settings ultimately drives: a running controller
/// produces a visible tooltip, and completing/skipping removes it again.
/// Also guards the L-09 change directly: the tooltip's "Pause" button was
/// removed since a pause with no way to resume was a dead end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A second real rootBundle.loadString() call for the same asset key, made
  // from a later test in this file, never resolves (a flutter_test asset
  // messenger quirk, not a production bug). Loading the JSON once up front
  // and handing every controller a loader that just returns it avoids
  // touching rootBundle more than once per file.
  late TutorialDefinition homeOnboarding;

  setUpAll(() async {
    final String raw = await rootBundle.loadString(
      'assets/tutorials/home.json',
    );
    homeOnboarding = TutorialDefinition.decode(raw);
  });

  Future<TutorialController> pumpHost(WidgetTester tester) async {
    final TutorialController controller = TutorialController(
      loader: _PreloadedTutorialAssetLoader(homeOnboarding),
    );
    addTearDown(controller.dispose);

    await controller.loadAssets(<String>['assets/tutorials/home.json']);

    await tester.pumpWidget(
      MaterialApp(
        home: TutorialHost(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('an active step renders its tooltip title and body', (
    WidgetTester tester,
  ) async {
    final TutorialController controller = await pumpHost(tester);

    await controller.start('home_onboarding');
    await tester.pump();

    expect(controller.activeStep, isNotNull);
    expect(find.text(controller.activeStep!.title), findsOneWidget);
    expect(find.text(controller.activeStep!.body), findsOneWidget);
  });

  testWidgets('the tooltip no longer offers a Pause action', (
    WidgetTester tester,
  ) async {
    final TutorialController controller = await pumpHost(tester);

    await controller.start('home_onboarding');
    await tester.pump();

    expect(find.text('Pause'), findsNothing);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next Tip'), findsOneWidget);
  });

  testWidgets('skipping the tutorial removes the overlay', (
    WidgetTester tester,
  ) async {
    final TutorialController controller = await pumpHost(tester);

    await controller.start('home_onboarding');
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Skip'), findsNothing);
    expect(controller.running, isFalse);
  });
}

class _PreloadedTutorialAssetLoader extends TutorialAssetLoader {
  const _PreloadedTutorialAssetLoader(this.definition);

  final TutorialDefinition definition;

  @override
  Future<List<TutorialDefinition>> loadAll(List<String> paths) async =>
      <TutorialDefinition>[definition];
}
