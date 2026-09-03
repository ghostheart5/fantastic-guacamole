import 'package:fantastic_guacamole/features/home/ui/first_use_context_offer_card.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/golden_harness.dart';

void main() {
  setUpAll(loadAppFontsForGolden);

  testWidgets('semantics explain optional use-only context before actions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpOffer(tester, const Size(320, 568));

    final SemanticsNode offer = tester.getSemantics(
      find.byKey(const Key('first-use-context-offer')),
    );
    expect(
      offer.label,
      contains(
        'Optional current-priority context. Use only this time remains the default.',
      ),
    );
    expect(find.bySemanticsLabel('Add optional context'), findsOneWidget);
    expect(find.bySemanticsLabel('Not now'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('first-use-context-dismiss')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('first-use-context-dismiss')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final ({String name, Size size}) fixture in <({String name, Size size})>[
    (name: 'compact_320', size: const Size(320, 568)),
    (name: 'regular_375', size: const Size(375, 667)),
  ]) {
    testWidgets('${fixture.name} remains readable at 200 percent text', (
      WidgetTester tester,
    ) async {
      await _pumpOffer(tester, fixture.size);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('offer-capture')),
        matchesGoldenFile(
          platformGoldenFile('first_use_context_${fixture.name}_200.png'),
        ),
      );
    });
  }
}

Future<void> _pumpOffer(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: RepaintBoundary(
        key: const Key('offer-capture'),
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 1,
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: const Scaffold(
            backgroundColor: Color(0xFF050D1A),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: FirstUseContextOfferCard(
                    immediateGoal: 'Prepare the closed-test release safely.',
                    onAdd: _noop,
                    onDismiss: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _noop() {}
