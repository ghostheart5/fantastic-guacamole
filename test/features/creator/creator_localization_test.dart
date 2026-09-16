import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (CreatorFormKind.task, 'Tarea', 'Task'),
    (CreatorFormKind.goal, 'Meta', 'Goal'),
    (CreatorFormKind.habit, 'Ritmo diario', 'Daily Rhythm'),
    (CreatorFormKind.note, 'Nota', 'Note'),
  ]) {
    testWidgets(
      'Spanish ${scenario.$3} form preserves canonical type and entered text',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        CreatorFormData? saved;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicForm(
                  initialType: scenario.$1,
                  onSubmit: (data) async => saved = data,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(scenario.$2), findsOneWidget);
        expect(
          find.text('DETALLES: ${scenario.$2.toUpperCase()}'),
          findsOneWidget,
        );
        final submit = find.text('CREAR ${scenario.$2.toUpperCase()}');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(
          find.textContaining('Añade un título antes de crear'),
          findsOneWidget,
        );
        expect(saved, isNull);
        await tester.enterText(
          find.byType(TextField).first,
          'Mañana: revisar el uniforme',
        );
        await tester.enterText(
          find.byType(TextField).last,
          'Do not translate my entered text.',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(saved?.type, scenario.$3);
        expect(saved?.title, 'Mañana: revisar el uniforme');
        expect(saved?.description, 'Do not translate my entered text.');
        tester.view.physicalSize = const Size(320, 800);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
