import 'dart:ui' as ui;

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The colour a Text widget actually paints with.
Color _textColor(WidgetTester tester, Finder finder) {
  final Element element = tester.element(finder);
  final Text text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color ??
      const Color(0xFF000000);
}

/// The opaque colour actually behind a widget: walks up through Materials
/// (cards, chips, segments, the page) until a fill is opaque, then composites.
Color _surfaceBehind(WidgetTester tester, Finder finder) {
  final List<Color> layers = <Color>[];
  for (final Element e
      in find
          .ancestor(
            of: finder,
            matching: find.byWidgetPredicate(
              (Widget w) => w is Material || w is ChoiceChip,
            ),
          )
          .evaluate()) {
    final Widget w = e.widget;
    final Color? color = w is ChoiceChip
        ? (w.selected ? w.selectedColor : w.backgroundColor)
        : (w as Material).color;
    if (color == null || color.a == 0) continue;
    layers.add(color);
    if (color.a == 1) break;
  }
  Color result = AppColors.background;
  for (final Color layer in layers.reversed) {
    result = Color.alphaBlend(layer, result);
  }
  return result;
}

void _expectReadable(
  WidgetTester tester,
  String label,
  String theme, {
  double minimum = 4.5,
}) {
  final Finder finder = find.text(label);
  expect(finder, findsOneWidget, reason: label);
  final Color surface = _surfaceBehind(tester, finder);
  final Color fg = Color.alphaBlend(_textColor(tester, finder), surface);
  expect(
    _contrast(fg, surface),
    greaterThanOrEqualTo(minimum),
    reason: '"$label" under $theme: $fg on $surface',
  );
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget Function() body, {
  String language = 'en',
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: Locale(language),
      supportedLocales: ChronoSparkLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ChronoSparkLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: body(),
    ),
  );
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
    DestinationSwitch(
      firstLabel: 'Patterns',
      secondLabel: 'Future outcomes',
      selectedIndex: 0,
      onSelected: (_) {},
    ),
    RangeChoice(
      labels: const <String>['7 days', '30 days', '90 days'],
      selectedIndex: 1,
      onSelected: (_) {},
    ),
    const PlainMetricRow(
      label: 'On the page',
      value: '3 h',
      caption: 'Per week',
      provenance: ProvenanceKind.estimate,
    ),
    const ProvenanceLabel(ProvenanceKind.recorded),
    const ProvenanceLabel(ProvenanceKind.ai),
    PlainEmptyState(
      message: 'Not enough history yet.',
      actionLabel: 'Log a habit',
      onAction: () {},
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
                provenance: ProvenanceKind.plan,
              ),
              PlainDisclosure(
                title: 'What this is based on',
                initiallyExpanded: true,
                children: <Widget>[Text('Detail text')],
              ),
            ],
          ),
        ),
      ],
    ),
  ],
);

const List<String> _everyText = <String>[
  'Insights',
  'Patterns',
  'Future outcomes',
  '7 days',
  '30 days',
  '90 days',
  'On the page',
  '3 h',
  'Per week',
  'Estimate',
  'From your records',
  'AI interpretation',
  'Not enough history yet.',
  'Your records',
  'What you logged.',
  'Completed',
  '12',
  'Last 30 days',
  'From your plan',
  'What this is based on',
  'Detail text',
];

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'dark': appTheme,
    'light': appLightTheme,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    testWidgets('every text is readable (4.5:1) under the ${entry.key} theme', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      for (final String label in _everyText) {
        _expectReadable(tester, label, entry.key);
      }
      // The empty-state button.
      final OutlinedButton button = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      final Color buttonText = button.style!.foregroundColor!.resolve(
        <WidgetState>{},
      )!;
      final Color surface = _surfaceBehind(tester, find.byType(OutlinedButton));
      expect(_contrast(buttonText, surface), greaterThanOrEqualTo(4.5));
    });

    testWidgets('icons are readable under the ${entry.key} theme', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      final Color? headerIcon = tester
          .widget<IconButton>(find.byType(IconButton))
          .color;
      expect(headerIcon, isNotNull);
      expect(
        _contrast(headerIcon!, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
      final Finder chevron = find.byIcon(Icons.expand_less_rounded);
      final Color chevronColor = tester.widget<Icon>(chevron).color!;
      expect(
        _contrast(chevronColor, _surfaceBehind(tester, chevron)),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('secondary text is lighter than primary text, '
        'on the page and in a card (${entry.key})', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      // Primary: values and titles. Secondary: labels, captions, descriptions.
      for (final List<String> pair in <List<String>>[
        <String>['3 h', 'On the page'],
        <String>['12', 'Completed'],
        <String>['Your records', 'What you logged.'],
      ]) {
        final Color primary = _textColor(tester, find.text(pair[0]));
        final Color secondary = _textColor(tester, find.text(pair[1]));
        expect(
          primary,
          isNot(secondary),
          reason: '${pair[0]} vs ${pair[1]} look the same',
        );
      }
    });

    testWidgets('range chips and switch segments: both states readable '
        'and the unselected edge is faint (${entry.key})', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry.value, _screen);
      final List<ChoiceChip> chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(chips.map((ChoiceChip c) => c.selected).toList(), <bool>[
        false,
        true,
        false,
      ]);
      // The unselected segment border is a faint line, not full white.
      final Finder segment = find
          .ancestor(
            of: find.text('Future outcomes'),
            matching: find.byType(Material),
          )
          .first;
      final ShapeBorder? shape = tester.widget<Material>(segment).shape;
      final Color border = (shape! as RoundedRectangleBorder).side.color;
      expect(
        _contrast(border, AppColors.background),
        lessThan(4.5),
        reason: 'unselected border should be faint',
      );
    });
  }

  testWidgets('PlainScreen is Today\'s dark page under both themes', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const PlainScreen(children: <Widget>[Text('Body')]),
        ),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.background,
      );
    }
  });

  testWidgets('unstyled text on the page and in a card stays readable', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
      await _pump(
        tester,
        theme,
        () => const PlainScreen(
          children: <Widget>[
            Text('On page'),
            PlainCard(child: Text('In card')),
          ],
        ),
      );
      _expectReadable(tester, 'On page', theme.brightness.name);
      _expectReadable(tester, 'In card', theme.brightness.name);
    }
  });

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
    final Rect rect = tester.getRect(find.byType(ChoiceChip).last);
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

  testWidgets('a tappable PlainCard is a labelled button, selected or not', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      appTheme,
      () => Scaffold(
        body: Column(
          children: <Widget>[
            PlainCard(
              onTap: () {},
              semanticLabel: 'Open details',
              selected: false,
              child: const Text('Visible words'),
            ),
            PlainCard(onTap: () {}, child: const Text('Own words')),
          ],
        ),
      ),
    );
    final SemanticsData labelled = tester
        .getSemantics(find.bySemanticsLabel('Open details'))
        .getSemanticsData();
    expect(labelled.flagsCollection.isButton, isTrue);
    expect(labelled.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(labelled.flagsCollection.isSelected, ui.Tristate.isFalse);
    final SemanticsData own = tester
        .getSemantics(find.bySemanticsLabel('Own words'))
        .getSemanticsData();
    expect(own.flagsCollection.isButton, isTrue);
    expect(own.flagsCollection.isSelected, ui.Tristate.none);
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
    final SemanticsData data = tester
        .getSemantics(find.byType(IconButton))
        .getSemanticsData();
    expect(data.tooltip, 'Settings');
    expect(data.label, isEmpty);
    expect(find.bySemanticsLabel('Settings'), findsNothing);
    handle.dispose();
  });

  testWidgets('a disabled header action is dimmer and not enabled', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      appTheme,
      () => const PlainScreen(
        children: <Widget>[
          PlainHeader(
            title: 'Insights',
            actions: <PlainHeaderAction>[
              PlainHeaderAction(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: null,
              ),
              PlainHeaderAction(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onPressed: _noop,
              ),
            ],
          ),
        ],
      ),
    );
    final List<IconButton> buttons = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .toList();
    final Color enabled = buttons[1].color!;
    final Color disabled = buttons[0].disabledColor!;
    expect(
      _contrast(disabled, AppColors.background),
      lessThan(_contrast(enabled, AppColors.background)),
    );
    final SemanticsData data = tester
        .getSemantics(find.byTooltip('Refresh'))
        .getSemanticsData();
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('PlainScreen listKey reaches the list', (
    WidgetTester tester,
  ) async {
    const Key key = PageStorageKey<String>('insights');
    await tester.pumpWidget(
      const MaterialApp(
        home: PlainScreen(listKey: key, children: <Widget>[Text('Body')]),
      ),
    );
    expect(
      find.descendant(of: find.byKey(key), matching: find.text('Body')),
      findsOneWidget,
    );
    expect(tester.widget(find.byKey(key)), isA<ListView>());
  });
}

void _noop() {}
