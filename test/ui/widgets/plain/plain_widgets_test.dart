import 'dart:ui' as ui;

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpPlain(
  WidgetTester tester,
  Widget child, {
  String language = 'en',
  double width = 800,
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

/// Every widget in the kit with long content, for the overflow test.
Widget everything(String language) {
  final bool es = language == 'es';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      PlainHeader(
        title: es ? 'Resultados futuros de tus hábitos' : 'Future outcomes',
        actions: <PlainHeaderAction>[
          PlainHeaderAction(
            icon: Icons.settings_outlined,
            label: es ? 'Ajustes' : 'Settings',
            onPressed: () {},
          ),
        ],
      ),
      PlainSection(
        title: es ? 'Lo que muestran tus registros' : 'What your records show',
        description: es
            ? 'Una descripción larga de una sola línea para esta sección.'
            : 'A long one line description for this section of the page.',
        children: <Widget>[
          PlainCard(
            onTap: () {},
            semanticLabel: 'Open',
            child: const Text('A card with some content inside it'),
          ),
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PlainMetricRow(
                  label: es
                      ? 'Tareas terminadas a tiempo en las últimas semanas'
                      : 'Tasks finished on time across the last several weeks',
                  value: es ? 'unas 12 a 15' : 'about 12 to 15',
                  caption: es
                      ? 'Calculado con tus registros de este periodo'
                      : 'Calculated from your records for this period',
                  provenance: ProvenanceKind.estimate,
                ),
                PlainDisclosure(
                  title: es ? 'En qué se basa esto' : 'What this is based on',
                  initiallyExpanded: true,
                  children: <Widget>[
                    Text(
                      es
                          ? 'Se basa en tus registros de las últimas semanas.'
                          : 'Based on your records from the last few weeks.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          RangeChoice(
            labels: es
                ? <String>['7 días', '30 días', '90 días']
                : <String>['7 days', '30 days', '90 days'],
            selectedIndex: 1,
            onSelected: (_) {},
          ),
          DestinationSwitch(
            firstLabel: es ? 'Patrones' : 'Patterns',
            secondLabel: es ? 'Resultados futuros' : 'Future outcomes',
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          PlainEmptyState(
            message: es
                ? 'Aún no hay suficiente historial para mostrar esto.'
                : 'There is not enough history yet to show this.',
            actionLabel: es ? 'Registrar un hábito' : 'Log a habit',
            onAction: () {},
          ),
          const ProvenanceLabel(ProvenanceKind.ai),
        ],
      ),
    ],
  );
}

void main() {
  group('rendering', () {
    testWidgets('PlainScreen frames children, shows leading, refreshes', (
      WidgetTester tester,
    ) async {
      int refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: PlainScreen(
            leading: const Text('Back control'),
            onRefresh: () async => refreshes++,
            children: const <Widget>[Text('Body')],
          ),
        ),
      );
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Back control'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFF050D1A),
      );
      await tester.fling(find.text('Body'), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(refreshes, 1);
    });

    testWidgets('PlainScreen has no back control by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlainScreen(children: <Widget>[Text('Body')])),
      );
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('PlainHeader shows title and actions that fire', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpPlain(
        tester,
        PlainHeader(
          title: 'Insights',
          actions: <PlainHeaderAction>[
            PlainHeaderAction(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onPressed: () => taps++,
            ),
          ],
        ),
      );
      expect(find.text('Insights'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      expect(taps, 1);
    });

    testWidgets('PlainSection shows heading, description and children', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainSection(
          title: 'Habits',
          description: 'What you logged.',
          children: <Widget>[Text('Child one')],
        ),
      );
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('What you logged.'), findsOneWidget);
      expect(find.text('Child one'), findsOneWidget);
    });

    testWidgets('PlainCard shows content and reports taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpPlain(
        tester,
        PlainCard(
          onTap: () => taps++,
          semanticLabel: 'Open details',
          child: const Text('Card content'),
        ),
      );
      expect(find.text('Card content'), findsOneWidget);
      await tester.tap(find.text('Card content'));
      expect(taps, 1);
    });

    testWidgets('PlainMetricRow shows label, value, caption, provenance', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainMetricRow(
          label: 'Completed',
          value: '12',
          caption: 'Last 30 days',
          provenance: ProvenanceKind.recorded,
        ),
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('From your records'), findsOneWidget);
    });

    testWidgets('PlainMetricRow omits caption and provenance when absent', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainMetricRow(label: 'Completed', value: '12'),
      );
      expect(find.byType(ProvenanceLabel), findsNothing);
    });

    testWidgets('PlainDisclosure toggles and announces its state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPlain(
        tester,
        const PlainDisclosure(
          title: 'What this is based on',
          children: <Widget>[Text('Hidden details')],
        ),
      );
      expect(find.text('Hidden details'), findsNothing);
      var node = tester
          .getSemantics(find.bySemanticsLabel('What this is based on'))
          .getSemanticsData();
      expect(node.flagsCollection.isExpanded, isNot(ui.Tristate.none));
      expect(node.flagsCollection.isExpanded, ui.Tristate.isFalse);

      await tester.tap(find.text('What this is based on'));
      await tester.pump();
      expect(find.text('Hidden details'), findsOneWidget);
      node = tester
          .getSemantics(find.bySemanticsLabel('What this is based on'))
          .getSemanticsData();
      expect(node.flagsCollection.isExpanded, ui.Tristate.isTrue);

      await tester.tap(find.text('What this is based on'));
      await tester.pump();
      expect(find.text('Hidden details'), findsNothing);
      handle.dispose();
    });

    testWidgets('RangeChoice shows one selected chip and reports taps', (
      WidgetTester tester,
    ) async {
      final List<int> picked = <int>[];
      await pumpPlain(
        tester,
        RangeChoice(
          labels: const <String>['7 days', '30 days', '90 days'],
          selectedIndex: 1,
          onSelected: picked.add,
        ),
      );
      final List<ChoiceChip> chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(chips.length, 3);
      expect(chips.map((ChoiceChip c) => c.selected).toList(), <bool>[
        false,
        true,
        false,
      ]);
      await tester.tap(find.text('90 days'));
      expect(picked, <int>[2]);
    });

    testWidgets('DestinationSwitch reports taps and marks one selected', (
      WidgetTester tester,
    ) async {
      final List<int> picked = <int>[];
      await pumpPlain(
        tester,
        DestinationSwitch(
          firstLabel: 'Patterns',
          secondLabel: 'Future outcomes',
          selectedIndex: 0,
          onSelected: picked.add,
        ),
      );
      expect(find.text('Patterns'), findsOneWidget);
      expect(find.text('Future outcomes'), findsOneWidget);
      await tester.tap(find.text('Future outcomes'));
      expect(picked, <int>[1]);
    });

    testWidgets('PlainEmptyState shows message and optional action', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpPlain(
        tester,
        PlainEmptyState(
          message: 'Not enough history yet.',
          actionLabel: 'Log a habit',
          onAction: () => taps++,
        ),
      );
      expect(find.text('Not enough history yet.'), findsOneWidget);
      await tester.tap(find.text('Log a habit'));
      expect(taps, 1);
    });

    testWidgets('PlainEmptyState without an action shows no button', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainEmptyState(message: 'Not enough history yet.'),
      );
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('ProvenanceLabel text', () {
    const Map<ProvenanceKind, List<String>> expected =
        <ProvenanceKind, List<String>>{
          ProvenanceKind.recorded: <String>[
            'From your records',
            'De tus registros',
          ],
          ProvenanceKind.plan: <String>['From your plan', 'De tu plan'],
          ProvenanceKind.estimate: <String>['Estimate', 'Estimación'],
          ProvenanceKind.ai: <String>[
            'AI interpretation',
            'Interpretación de IA',
          ],
        };
    for (final ProvenanceKind kind in ProvenanceKind.values) {
      testWidgets('${kind.name} in English and Spanish', (
        WidgetTester tester,
      ) async {
        await pumpPlain(tester, ProvenanceLabel(kind));
        expect(find.text(expected[kind]![0]), findsOneWidget);
        await pumpPlain(tester, ProvenanceLabel(kind), language: 'es');
        expect(find.text(expected[kind]![1]), findsOneWidget);
      });
    }
  });

  group('selection state', () {
    testWidgets('DestinationSwitch segments have labels; selected is marked', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPlain(
        tester,
        DestinationSwitch(
          firstLabel: 'Patterns',
          secondLabel: 'Future outcomes',
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      );
      final first = tester
          .getSemantics(find.bySemanticsLabel('Patterns'))
          .getSemanticsData();
      final second = tester
          .getSemantics(find.bySemanticsLabel('Future outcomes'))
          .getSemanticsData();
      expect(first.flagsCollection.isSelected, ui.Tristate.isFalse);
      expect(second.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(first.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('PlainHeader actions have semantics labels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPlain(
        tester,
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
      );
      expect(
        tester.getSemantics(find.byType(IconButton)).getSemanticsData().tooltip,
        'Settings',
      );
      handle.dispose();
    });
  });

  group('tap targets are at least 48 x 48', () {
    void expectBig(WidgetTester tester, Finder finder) {
      expect(finder, findsWidgets);
      for (final Element e in finder.evaluate()) {
        final Size size = tester.getSize(find.byWidget(e.widget));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$finder width');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$finder height');
      }
    }

    testWidgets('header action', (WidgetTester tester) async {
      await pumpPlain(
        tester,
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
      );
      expectBig(tester, find.byType(IconButton));
    });

    testWidgets('tappable card, even with tiny content', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: PlainCard(onTap: () {}, child: const SizedBox(width: 4)),
        ),
      );
      expectBig(tester, find.byType(InkWell));
    });

    testWidgets('disclosure, destination segments, empty-state button', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        Column(
          children: <Widget>[
            const PlainDisclosure(title: 'Why', children: <Widget>[]),
            DestinationSwitch(
              firstLabel: 'A',
              secondLabel: 'B',
              selectedIndex: 0,
              onSelected: (_) {},
            ),
            PlainEmptyState(
              message: 'Nothing yet.',
              actionLabel: 'Go',
              onAction: () {},
            ),
          ],
        ),
      );
      expectBig(tester, find.byType(InkWell));
      expectBig(tester, find.byType(OutlinedButton));
    });

    // Range chip hit areas are tested at their edges in plain_theme_test.dart.
  });

  group('API additions', () {
    testWidgets('PlainDisclosure can start open and keeps its state', (
      WidgetTester tester,
    ) async {
      Widget build(String extra) => PlainDisclosure(
        key: const ValueKey<String>('why'),
        title: 'Why',
        initiallyExpanded: true,
        children: <Widget>[Text('Detail $extra')],
      );
      await pumpPlain(tester, build('one'));
      expect(find.text('Detail one'), findsOneWidget);
      await tester.tap(find.text('Why'));
      await tester.pump();
      expect(find.text('Detail one'), findsNothing);
      await pumpPlain(tester, build('two'));
      expect(find.textContaining('Detail'), findsNothing);
    });

    testWidgets('PlainCard selected is announced and not set by default', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPlain(
        tester,
        Column(
          children: <Widget>[
            PlainCard(
              selected: true,
              onTap: () {},
              semanticLabel: 'Chosen',
              child: const Text('Chosen'),
            ),
            const PlainCard(child: Text('Plain content')),
          ],
        ),
      );
      final chosen = tester
          .getSemantics(find.bySemanticsLabel('Chosen'))
          .getSemanticsData();
      expect(chosen.flagsCollection.isSelected, ui.Tristate.isTrue);
      final plain = tester
          .getSemantics(find.bySemanticsLabel('Plain content'))
          .getSemanticsData();
      expect(plain.flagsCollection.isSelected, ui.Tristate.none);
      handle.dispose();
    });

    testWidgets('PlainHeaderAction with no callback is disabled', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainHeader(
          title: 'Insights',
          actions: <PlainHeaderAction>[
            PlainHeaderAction(
              icon: Icons.refresh,
              label: 'Refresh',
              onPressed: null,
            ),
          ],
        ),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });

    testWidgets('DestinationSwitch segments form one exclusive group', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPlain(
        tester,
        DestinationSwitch(
          firstLabel: 'Patterns',
          secondLabel: 'Future outcomes',
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Patterns'))
          .getSemanticsData();
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      handle.dispose();
    });

    testWidgets('PlainScreen passes its controller to the list', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PlainScreen(
            controller: controller,
            children: const <Widget>[Text('Body')],
          ),
        ),
      );
      expect(controller.hasClients, isTrue);
    });
  });

  group('layout when space is short (text scale 2.0, 320 wide)', () {
    testWidgets('DestinationSwitch stacks its segments', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DestinationSwitch(
            firstLabel: 'Patrones',
            secondLabel: 'Resultados futuros',
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
        language: 'es',
        width: 320,
        textScale: 2.0,
      );
      final Rect a = tester.getRect(find.text('Patrones'));
      final Rect b = tester.getRect(find.text('Resultados futuros'));
      expect(b.top, greaterThanOrEqualTo(a.bottom));
      // Stacked: each segment spans the full 280 dp, not half of it.
      expect(tester.getSize(find.byType(InkWell).first).width, 280);
      expect(tester.getSize(find.byType(InkWell).last).width, 280);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PlainMetricRow puts a wide value under its label', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: PlainMetricRow(label: 'Completed', value: '12 to 15'),
        ),
        width: 320,
        textScale: 2.0,
      );
      expect(
        tester.getRect(find.text('12 to 15')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Completed')).bottom),
      );
    });

    testWidgets('PlainMetricRow keeps a short value beside its label', (
      WidgetTester tester,
    ) async {
      await pumpPlain(
        tester,
        const PlainMetricRow(label: 'Completed', value: '12'),
      );
      expect(
        tester.getRect(find.text('12')).left,
        greaterThan(tester.getRect(find.text('Completed')).right),
      );
    });
  });

  group('no overflow at text scale 2.0 on a 320 wide screen', () {
    for (final String language in <String>['en', 'es']) {
      for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
        testWidgets('all widgets, $language, ${theme.brightness.name}', (
          WidgetTester tester,
        ) async {
          await pumpPlain(
            tester,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: everything(language),
            ),
            language: language,
            width: 320,
            textScale: 2.0,
            theme: theme,
          );
          expect(tester.takeException(), isNull);
          // Values are wrapped at spaces, not truncated.
          expect(
            find.text(language == 'es' ? 'unas 12 a 15' : 'about 12 to 15'),
            findsOneWidget,
          );
        });
      }
    }

    for (final String language in <String>['en', 'es']) {
      for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
        testWidgets(
          'PlainScreen at 2.0 and 320, $language, ${theme.brightness.name}',
          (WidgetTester tester) async {
            tester.view.physicalSize = const Size(320, 1600);
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = 2.0;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearAllTestValues);
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
                home: PlainScreen(children: <Widget>[everything(language)]),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
