import 'dart:ui' as ui;

import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _opaque(Color fg, Color bg) => Color.alphaBlend(fg, bg);

/// The colour a Text widget actually paints with.
Color _textColor(WidgetTester tester, Finder finder) {
  final Element element = tester.element(finder);
  final Text text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color ??
      const Color(0xFF000000);
}

/// The surface directly behind a widget: the nearest Card, else the page.
Color _surface(WidgetTester tester, Finder finder, Color page) {
  final Iterable<Element> cards = find
      .ancestor(of: finder, matching: find.byType(Card))
      .evaluate();
  if (cards.isEmpty) return page;
  final Card card = cards.first.widget as Card;
  final CardThemeData cardTheme = Theme.of(cards.first).cardTheme;
  return _opaque(card.color ?? cardTheme.color ?? page, page);
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget Function() body,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: theme, home: body()));
  await tester.pump();
}

Widget _screen() => PlainScreen(
  children: <Widget>[
    PlainHeader(
      title: 'Insights',
      actions: <PlainHeaderAction>[
        PlainHeaderAction(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onPressed: () {},
        ),
      ],
    ),
    const PlainSection(
      title: 'Your records',
      description: 'What you logged.',
      children: <Widget>[
        PlainCard(
          child: Column(
            children: <Widget>[
              PlainMetricRow(
                label: 'Completed',
                value: '12',
                caption: 'Last 30 days',
                provenance: ProvenanceKind.estimate,
              ),
              PlainDisclosure(
                title: 'What this is based on',
                children: <Widget>[Text('Detail text')],
              ),
            ],
          ),
        ),
      ],
    ),
  ],
);

void main() {
  pageColourTests();
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'dark': appTheme,
    'light': appLightTheme,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    testWidgets('text is readable (4.5:1) under the ${entry.key} theme', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      await tester.tap(find.text('What this is based on'));
      await tester.pump();
      final Color page = tester
          .widget<Scaffold>(find.byType(Scaffold))
          .backgroundColor!;
      for (final String label in <String>[
        'Insights',
        'Your records',
        'What you logged.',
        'Completed',
        '12',
        'Last 30 days',
        'Estimate',
        'What this is based on',
        'Detail text',
      ]) {
        final Finder finder = find.text(label);
        final Color surface = _surface(tester, finder, page);
        final Color fg = _opaque(_textColor(tester, finder), surface);
        expect(
          _contrast(fg, surface),
          greaterThanOrEqualTo(4.5),
          reason: '"$label" under ${entry.key}: $fg on $surface',
        );
      }
    });

    testWidgets('header icon is readable under the ${entry.key} theme', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      final Color page = tester
          .widget<Scaffold>(find.byType(Scaffold))
          .backgroundColor!;
      final Color? icon = tester
          .widget<IconButton>(find.byType(IconButton))
          .color;
      expect(icon, isNotNull);
      expect(_contrast(_opaque(icon!, page), page), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('range chip hit area reaches 2 dp inside its 48 dp edges', (
    WidgetTester tester,
  ) async {
    final List<int> picked = <int>[];
    await _pump(
      tester,
      appTheme,
      () => Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RangeChoice(
            labels: const <String>['7 days', '30 days'],
            selectedIndex: 0,
            onSelected: picked.add,
          ),
        ),
      ),
    );
    final Finder chip = find.byType(ChoiceChip).last;
    final Rect rect = tester.getRect(chip);
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.width, greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 2));
    expect(picked, <int>[1, 1]);
  });

  testWidgets('RangeChoice announces exactly one chip as selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      appTheme,
      () => Scaffold(
        body: RangeChoice(
          labels: const <String>['7 days', '30 days', '90 days'],
          selectedIndex: 2,
          onSelected: (_) {},
        ),
      ),
    );
    final List<bool> selected = <bool>[
      for (final String label in <String>['7 days', '30 days', '90 days'])
        tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
    ];
    expect(selected, <bool>[false, false, true]);
    handle.dispose();
  });

  testWidgets('a tappable PlainCard is a labelled button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      appTheme,
      () => Scaffold(
        body: PlainCard(
          onTap: () {},
          semanticLabel: 'Open details',
          child: const Text('Visible words'),
        ),
      ),
    );
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Open details'),
    );
    final SemanticsData data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('a header action is announced once, with exactly its label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      appTheme,
      () => Scaffold(
        body: PlainHeader(
          title: 'Insights',
          actions: <PlainHeaderAction>[
            PlainHeaderAction(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    final data = tester
        .getSemantics(find.byType(IconButton))
        .getSemanticsData();
    expect(data.tooltip, 'Settings');
    expect(data.label, isEmpty);
    expect(find.bySemanticsLabel('Settings'), findsNothing);
    handle.dispose();
  });
}

void pageColourTests() {
  testWidgets('PlainScreen page colour follows the light theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: const PlainScreen(children: <Widget>[Text('Body')]),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      appLightTheme.scaffoldBackgroundColor,
    );
  });
}
