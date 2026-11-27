import 'dart:ui' as ui;

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AppView current, {
  String language = 'en',
  double width = 400,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          backgroundColor: const Color(0xFF05070D),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: InsightsDestinationSwitch(current: current),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

SemanticsData _node(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label).last).getSemanticsData();

void main() {
  testWidgets('shows both names with the shown destination selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, AppView.trajectoryEngine);
    expect(find.text('Future outcomes'), findsOneWidget);
    expect(find.text('Patterns'), findsOneWidget);
    expect(
      _node(tester, 'Future outcomes').flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      _node(tester, 'Patterns').flagsCollection.isSelected,
      ui.Tristate.isFalse,
    );
    handle.dispose();
  });

  testWidgets('Patterns is selected on Patterns, in Spanish too', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, AppView.progression, language: 'es');
    expect(find.text('Resultados futuros'), findsOneWidget);
    expect(find.text('Patrones'), findsOneWidget);
    expect(
      _node(tester, 'Patrones').flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      _node(tester, 'Resultados futuros').flagsCollection.isSelected,
      ui.Tristate.isFalse,
    );
    handle.dispose();
  });

  testWidgets('is announced as a mutually exclusive pair of buttons', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, AppView.trajectoryEngine);
    for (final String label in <String>['Future outcomes', 'Patterns']) {
      final SemanticsData node = _node(tester, label);
      expect(node.flagsCollection.isButton, isTrue, reason: label);
      expect(
        node.flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('moves both ways and Patterns remembers Future outcomes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(
      tester,
      AppView.trajectoryEngine,
    );
    await tester.tap(find.text('Future outcomes'));
    await tester.pump();
    // Already shown: nothing happens.
    expect(container.read(appFlowProvider), isNot(AppView.progression));
    expect(container.read(activityOriginProvider), isNull);

    await tester.tap(find.text('Patterns'));
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.progression);
    expect(container.read(activityOriginProvider), AppView.trajectoryEngine);
  });

  testWidgets('from Patterns the other segment opens Future outcomes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(
      tester,
      AppView.progression,
    );
    await tester.tap(find.text('Patterns'));
    await tester.pump();
    expect(container.read(appFlowProvider), isNot(AppView.trajectoryEngine));

    await tester.tap(find.text('Future outcomes'));
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.trajectoryEngine);
  });

  for (final AppView view in <AppView>[
    AppView.trajectoryEngine,
    AppView.progression,
  ]) {
    testWidgets('does not overflow at text scale 2.0 on 320 dp in Spanish '
        '(${view.name})', (WidgetTester tester) async {
      await _pump(tester, view, language: 'es', width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
      expect(find.text('Resultados futuros'), findsOneWidget);
      expect(find.text('Patrones'), findsOneWidget);
      final Size size = tester.getSize(
        find.byKey(InsightsDestinationSwitch.switchKey),
      );
      expect(size.width, lessThanOrEqualTo(320 - 40));
    });
  }

  testWidgets('a guidance hint card moves the switch down instead of covering '
      'it (360x640)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) => Stack(
            children: <Widget>[
              GuideHintSpace(child: child ?? const SizedBox.shrink()),
              // A card as tall as a real hint, drawn over the top of the app.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: ColoredBox(color: Color(0xFF223344)),
              ),
            ],
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: InsightsDestinationSwitch(current: AppView.progression),
            ),
          ),
        ),
      ),
    );
    container
        .read(guideHintReservedHeightProvider.notifier)
        .reserve(Object(), 150);
    await tester.pump();
    await tester.pump();
    final Rect rect = tester.getRect(
      find.byKey(InsightsDestinationSwitch.switchKey),
    );
    expect(rect.top, greaterThanOrEqualTo(150));
    await tester.tap(find.text('Future outcomes'), warnIfMissed: true);
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.trajectoryEngine);
  });
}
