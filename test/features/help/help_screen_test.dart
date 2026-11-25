import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/features/help/help_topics.dart';
import 'package:fantastic_guacamole/features/help/ui/help_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ValueKey<String> _pageKey = ValueKey<String>('shared-shell-page');

/// Every page Help can send the person to, as the router would.
const Map<String, String> _pages = <String, String>{
  '/nexus': 'today page',
  '/timeline': 'my plan page',
  '/creator/goals': 'goals page',
  '/trajectory': 'insights page',
  '/settings/advanced/si-console': 'chat page',
  '/smart-planner': 'choose a step page',
  '/settings/advanced/progression': 'activity page',
};

void main() {
  late GoRouter router;

  /// Settings with a button that opens Help the way the Settings row does.
  Future<void> pumpFromSettings(
    WidgetTester tester, {
    required bool es,
    double textScale = 1,
    Size size = const Size(800, 1400),
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.platformDispatcher.views.first
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    router = GoRouter(
      initialLocation: '/settings',
      routes: <RouteBase>[
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: _pageKey,
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: <Widget>[
                    const Text('settings page'),
                    TextButton(
                      onPressed: () => openHelpScreen(context),
                      child: const Text('open help'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        for (final MapEntry<String, String> page in _pages.entries)
          GoRoute(
            path: page.key,
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: _pageKey,
              child: Scaffold(body: Text(page.value)),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: Locale(es ? 'es' : 'en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open help'));
    await tester.pumpAndSettle();
  }

  Finder topicTitle(GuidanceText title, bool es) =>
      find.text(title.of(spanish: es));

  Future<void> showTopic(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      maxScrolls: 200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// The Show me button on the topic titled [title].
  Finder showMeFor(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
    matching: find.byType(OutlinedButton),
  );

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  group('topics', () {
    test('every contextual hint has a Help topic, except the one whose text '
        'is about its own button; wording tied to the screen of the hint is '
        'replaced', () {
      // These hints say "here" or "these settings", or name only part of a
      // rule, so Help words them to stand on their own.
      const Set<GuidanceLessonId> reworded = <GuidanceLessonId>{
        GuidanceLessonId.habits,
        GuidanceLessonId.goals,
        GuidanceLessonId.notificationSettings,
      };
      for (final GuidanceHint hint in GuidanceCatalogue.hints) {
        final Iterable<HelpTopic> topics = HelpTopics.all.where(
          (HelpTopic topic) => topic.id == 'hint-${hint.id.name}',
        );
        if (hint.id == GuidanceLessonId.remindersOff) {
          expect(topics, isEmpty);
          continue;
        }
        expect(topics, hasLength(1), reason: hint.id.name);
        final HelpTopic topic = topics.single;
        final bool same =
            topic.title.en == hint.title.en &&
            topic.title.es == hint.title.es &&
            topic.body.en == hint.body.en &&
            topic.body.es == hint.body.es;
        expect(same, !reworded.contains(hint.id), reason: hint.id.name);
      }
    });

    test('no topic points at "here" or "these", which only make sense on '
        'the screen itself', () {
      final RegExp english = RegExp(r'\b(here|these|this screen)\b');
      final RegExp spanish = RegExp(
        r'(^|[^\p{L}])(aquí|estos|estas|esta pantalla)([^\p{L}]|$)',
        unicode: true,
        caseSensitive: false,
      );
      for (final HelpTopic topic in HelpTopics.all) {
        for (final GuidanceText? text in <GuidanceText?>[
          topic.title,
          topic.body,
          topic.whereToTap,
        ]) {
          if (text == null) continue;
          expect(
            english.hasMatch(text.en.toLowerCase()),
            isFalse,
            reason: text.en,
          );
          expect(spanish.hasMatch(text.es), isFalse, reason: text.es);
        }
      }
    });

    test('the suggested-step hint on Today says where its reasons are', () {
      final HelpTopic topic = HelpTopics.all.singleWhere(
        (HelpTopic topic) => topic.id == 'hint-nexus',
      );
      expect(topic.whereToTap?.en, 'On Today, tap Review my day in detail.');
      expect(topic.whereToTap?.es, 'En Hoy, toca Revisar mi día en detalle.');
    });

    test(
      'reminder topics state the rules Settings shows, in both languages',
      () {
        String text(String id, bool es) {
          final HelpTopic topic = HelpTopics.all.singleWhere(
            (HelpTopic topic) => topic.id == id,
          );
          return topic.body.of(spanish: es);
        }

        for (final bool es in <bool>[false, true]) {
          final String tasks = text('task-reminders', es);
          final String goals = text('goal-habit-reminders', es);
          final String late = text('late-reminders', es);
          final String missing = text('reminders-not-arriving', es);
          // The Task reminder time setting moves the reminder earlier, and
          // Overdue nudges add one the day after.
          expect(
            tasks,
            contains(
              es ? 'Hora del recordatorio de tareas' : 'Task reminder time',
            ),
          );
          expect(tasks, contains(es ? 'Avisos de vencidos' : 'Overdue nudges'));
          expect(tasks, contains(es ? '9:00' : '9 AM'));
          expect(tasks, contains('20'));
          // Goals: 9 AM slots, 6 PM same day, overdue, "almost there".
          expect(goals, contains(es ? 'tres días antes' : 'three days before'));
          expect(goals, contains(es ? '18:00' : '6 PM'));
          expect(goals, contains(es ? 'Avisos de vencidos' : 'Overdue nudges'));
          expect(goals, contains(es ? 'ya casi' : 'almost there'));
          expect(
            goals,
            contains(es ? 'sin hora no avisan' : 'without a time stays quiet'),
          );
          expect(
            late,
            contains(es ? 'varios minutos tarde' : 'several minutes late'),
          );
          expect(late, contains(es ? 'horas de silencio' : 'quiet hours'));
          // Every switch that can silence a reminder is named as Settings
          // names it.
          for (final String label
              in es
                  ? <String>[
                      'Recordatorios de tareas',
                      'Recordatorios de metas',
                      'Recordatorios de ritmos',
                    ]
                  : <String>[
                      'Task Reminders',
                      'Goal Reminders',
                      'Habit Reminders',
                    ]) {
            expect(missing, contains(label));
          }
          expect(
            missing,
            contains(
              es
                  ? 'sin hora de recordatorio no avisan'
                  : 'without a reminder time stays quiet',
            ),
          );
        }
      },
    );

    test('topics written for Help cover the main screens, reminders and '
        'the guide in both languages', () {
      final Set<String> titles = HelpTopics.all
          .map((HelpTopic topic) => topic.title.en)
          .toSet();
      expect(
        titles,
        containsAll(<String>[
          'What Today is for',
          'What My plan is for',
          'What Habits is for',
          'What Goals is for',
          'What Insights is for',
          'What Chat is for',
          'What Notifications settings are for',
          'How task reminders work',
          'How goal and habit reminders work',
          'Why a reminder can come late',
          'If reminders do not arrive',
          'Turn the guide back on',
        ]),
      );
      for (final HelpTopic topic in HelpTopics.all) {
        for (final GuidanceText? text in <GuidanceText?>[
          topic.title,
          topic.body,
          topic.place,
          topic.whereToTap,
        ]) {
          if (text == null) continue;
          expect(text.en.trim(), isNotEmpty, reason: topic.id);
          expect(text.es.trim(), isNotEmpty, reason: topic.id);
        }
        expect(topic.title.es, isNot(topic.title.en), reason: topic.id);
        expect(topic.body.es, isNot(topic.body.en), reason: topic.id);
        expect(topic.place, isNotNull, reason: topic.id);
        // A screen is named the way its navigation control names it.
        if (topic.showMe case final AppView view
            when topic.whereToTap == null) {
          for (final bool es in <bool>[false, true]) {
            expect(
              topic.place!.of(spanish: es),
              NavigationCopy(es).label(AppRouteRegistry.routeForView(view)),
              reason: topic.id,
            );
          }
        }
      }
      for (final AppView view in AppView.values) {
        for (final bool es in <bool>[false, true]) {
          expect(
            HelpTopics.screenName(view).of(spanish: es),
            NavigationCopy(es).label(AppRouteRegistry.routeForView(view)),
            reason: view.name,
          );
        }
      }
      expect(
        HelpTopics.all.map((HelpTopic topic) => topic.id).toSet(),
        hasLength(HelpTopics.all.length),
      );
    });

    test('search ignores case and accents and needs every word', () {
      final HelpTopic habits = HelpTopics.all.singleWhere(
        (HelpTopic topic) => topic.title.en == 'What Habits is for',
      );
      expect(habits.matches('HABITOS', spanish: true), isTrue);
      expect(habits.matches('hábitos', spanish: true), isTrue);
      expect(habits.matches('habits', spanish: true), isFalse);
      expect(habits.matches('Habits', spanish: false), isTrue);
      expect(habits.matches('habits zebra', spanish: false), isFalse);
      expect(habits.matches('   ', spanish: false), isTrue);
    });
  });

  for (final bool es in <bool>[false, true]) {
    final String lang = es ? 'Spanish' : 'English';

    testWidgets('$lang Help lists the written topics and the hints with '
        'their plain text', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);

      expect(find.text(es ? 'Ayuda' : 'Help'), findsOneWidget);
      expect(
        topicTitle(
          const GuidanceText('What Today is for', 'Para qué sirve Hoy'),
          es,
        ),
        findsOneWidget,
      );
      // The Choose a step hint shows its plain text, not today's variant.
      final Finder plannerBody = find.text(
        GuidanceCatalogue.smartPlanner.body.of(spanish: es),
      );
      await showTopic(tester, plannerBody);
      expect(plannerBody, findsOneWidget);
      final Finder restart = topicTitle(
        const GuidanceText(
          'Turn the guide back on',
          'Volver a activar la guía',
        ),
        es,
      );
      await showTopic(tester, restart);
      expect(
        find.textContaining(
          es ? 'Reiniciar la Guía Adaptativa' : 'Restart Adaptive Guide',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang search finds topics by words in the app language, '
        'ignoring case and accents', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);

      await search(tester, es ? 'HABITOS' : 'HABITS');
      expect(topicTitle(GuidanceCatalogue.habits.title, es), findsOneWidget);
      expect(
        topicTitle(
          const GuidanceText('What Today is for', 'Para qué sirve Hoy'),
          es,
        ),
        findsNothing,
      );

      // A word from the other language finds nothing.
      await search(tester, es ? 'quiet hours' : 'horas de silencio');
      expect(
        find.text(
          es
              ? 'Ningún tema coincide con «quiet hours».'
              : 'No topics match "horas de silencio".',
        ),
        findsOneWidget,
      );

      await search(tester, es ? 'silencio' : 'quiet hours');
      expect(
        topicTitle(
          const GuidanceText(
            'Why a reminder can come late',
            'Por qué un recordatorio puede llegar tarde',
          ),
          es,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang search with no match says so plainly and clearing it '
        'shows every topic again', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);

      await search(tester, 'zzqx');
      expect(
        find.text(
          es ? 'Ningún tema coincide con «zzqx».' : 'No topics match "zzqx".',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          es
              ? 'Prueba con otra palabra o borra la búsqueda para ver todos los temas.'
              : 'Try another word, or clear the search to see every topic.',
        ),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);

      await tester.tap(
        find.byTooltip(es ? 'Borrar la búsqueda' : 'Clear search'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsWidgets);
      expect(
        topicTitle(
          const GuidanceText('What Today is for', 'Para qué sirve Hoy'),
          es,
        ),
        findsOneWidget,
      );
    });

    testWidgets('$lang Show me closes Help and opens the screen', (
      WidgetTester tester,
    ) async {
      await pumpFromSettings(tester, es: es);

      await search(tester, es ? 'perspectivas' : 'insights');
      final Finder showMe = showMeFor(
        es ? 'Para qué sirve Perspectivas' : 'What Insights is for',
      );
      expect(
        find.descendant(
          of: showMe,
          matching: find.text(es ? 'Muéstramelo' : 'Show me'),
        ),
        findsOneWidget,
      );
      await tester.tap(showMe);
      await tester.pumpAndSettle();

      expect(find.byType(HelpScreen), findsNothing);
      expect(find.text('insights page'), findsOneWidget);
      final BuildContext page = tester.element(find.text('insights page'));
      expect(ModalRoute.of(page)!.isCurrent, isTrue);
    });

    testWidgets('$lang Habits has no route of its own: Show me opens Today '
        'and the topic says where to tap', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);

      await search(tester, es ? 'para qué sirve hábitos' : 'what habits');
      expect(
        find.text(
          es
              ? 'Para abrir Hábitos, ve a Hoy y toca Registrar un hábito.'
              : 'To open Habits, go to Today and tap Check in with a habit.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        showMeFor(es ? 'Para qué sirve Hábitos' : 'What Habits is for'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HelpScreen), findsNothing);
      expect(find.text('today page'), findsOneWidget);
    });

    testWidgets('$lang every Show me reaches its screen', (
      WidgetTester tester,
    ) async {
      for (final HelpTopic topic in HelpTopics.all.where(
        (HelpTopic topic) => topic.showMe != null,
      )) {
        await pumpFromSettings(tester, es: es);
        await search(tester, topic.title.of(spanish: es));
        final Finder button = showMeFor(topic.title.of(spanish: es));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(HelpScreen), findsNothing, reason: topic.id);
        expect(
          find.text(_pages[routePathForAppView(topic.showMe!)]!),
          findsOneWidget,
          reason: topic.id,
        );
      }
    });

    testWidgets('$lang topics about Settings offer no Show me and say where '
        'to tap', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);

      await search(tester, es ? 'volver a activar la guía' : 'guide back on');
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        find.text(
          es
              ? 'En Ajustes, abre Planificación y orientación y toca Reiniciar la Guía Adaptativa.'
              : 'In Settings, open Planning & guidance and tap Restart Adaptive Guide.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('$lang Back returns to Settings', (WidgetTester tester) async {
      await pumpFromSettings(tester, es: es);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsNothing);
      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('$lang Help is readable by a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpFromSettings(tester, es: es);

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(
          label: es ? 'Buscar en la ayuda' : 'Search help',
          isTextField: true,
        ),
      );
      final Finder title = find.text(
        es ? 'Para qué sirve Hoy' : 'What Today is for',
      );
      expect(
        tester.getSemantics(title),
        isSemantics(
          label: es ? 'Para qué sirve Hoy' : 'What Today is for',
          isHeader: true,
        ),
      );
      final Finder showMe = find.bySemanticsLabel(
        es ? 'Muéstramelo: Hoy' : 'Show me: Today',
      );
      expect(showMe, findsWidgets);
      expect(
        tester.getSize(find.byType(OutlinedButton).first).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.text(es ? 'Dónde: Hoy' : 'Where: Today'), findsWidgets);

      await search(tester, 'zzqx');
      final Size clear = tester.getSize(
        find.byTooltip(es ? 'Borrar la búsqueda' : 'Clear search'),
      );
      expect(clear.width, greaterThanOrEqualTo(48));
      expect(clear.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('$lang Help fits a 320 dp screen at 200% text', (
      WidgetTester tester,
    ) async {
      await pumpFromSettings(
        tester,
        es: es,
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      final Finder last = topicTitle(HelpTopics.all.last.title, es);
      await showTopic(tester, last);
      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byType(TextField),
        -400,
        maxScrolls: 200,
        scrollable: find.byType(Scrollable).first,
      );
      await search(tester, 'zzqx');
      expect(
        find.text(
          es ? 'Ningún tema coincide con «zzqx».' : 'No topics match "zzqx".',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reading Help stores nothing, so no hint is marked seen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpFromSettings(tester, es: false);
    await search(tester, 'reminder');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
