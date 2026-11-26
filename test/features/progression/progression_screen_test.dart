import 'dart:ui' as ui;

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/user_progress.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/patterns_screen_harness.dart';

/// The screen title: the tab name, not the same word on the switch below it.
Finder _title(String text) =>
    find.descendant(of: find.byType(PlainHeader), matching: find.text(text));

/// Patterns mounts and survives the states a real user hits. Section figures
/// are covered in patterns_structure_test.dart.
void main() {
  testWidgets('Spanish Patterns translates names and controls', (tester) async {
    await pumpPatterns(tester, locale: const Locale('es'));
    expect(_title('Perspectivas'), findsOneWidget);
    expect(find.byTooltip('Compartir progreso'), findsOneWidget);
    expect(find.text('Periodo'), findsOneWidget);
    expect(find.text('Hábitos'), findsOneWidget);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('TIER'), findsNothing);
    expect(find.textContaining('XP para el nivel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders for a brand-new account with zeroed progress', (
    tester,
  ) async {
    await pumpPatterns(tester, progression: ProgressionState.initial());
    expect(_title('Insights'), findsOneWidget);
    expect(
      find.text(
        'Nothing recorded in these days. Finish a task or check in a habit '
        'to see it here.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not enough evidence'), findsNothing);
    expect(find.text('Off Track'), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'A zeroed account is the first thing every new user sees.',
    );
  });

  testWidgets('fits a compact Pixel-width viewport without overflow', (
    tester,
  ) async {
    await pumpPatterns(
      tester,
      habits: <HabitEntity>[patternsHabit('walk')],
      size: const Size(412, 915),
    );
    expect(_title('Insights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved progress that cannot be loaded offers Retry, not zeros', (
    tester,
  ) async {
    await pumpPatterns(
      tester,
      progression: const ProgressionState(
        progress: UserProgress(xp: 0, level: 1, streak: 0, longestStreak: 0),
        loading: false,
        error: 'broken',
      ),
    );
    expect(
      find.text(
        'Your saved progress could not be loaded. No zero-value progress is '
        'being shown.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.text('Points'), findsNothing);
  });

  testWidgets('the whole Patterns screen fits at 2x text, 320 dp, Spanish, '
      'app theme', (WidgetTester tester) async {
    await pumpPatterns(
      tester,
      locale: const Locale('es'),
      size: const Size(320, 12000),
      textScale: 2.0,
      theme: appTheme,
      habits: <HabitEntity>[
        patternsHabit(
          'walk',
          title:
              'Caminar alrededor del parque grande con el perro cada '
              'mañana',
        ),
      ],
      tasks: [
        skippedTask(
          's',
          patternsAt(1),
          title: 'Llamar a la oficina de impuestos para revisar la declaración',
        ),
        openTask('u', title: 'Ordenar todas las fotos del viaje', minutes: 45),
      ],
    );
    // No drained error: nothing on the page overflows.
    expect(tester.takeException(), isNull);
    final Finder switchFinder = find.byKey(InsightsDestinationSwitch.switchKey);
    expect(switchFinder, findsOneWidget);
    expect(tester.getSize(switchFinder).width, lessThanOrEqualTo(320));
    expect(
      find.descendant(
        of: switchFinder,
        matching: find.text('Resultados futuros'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: switchFinder, matching: find.text('Patrones')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Patterns has no back control; the switch moves to Future outcomes',
    (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final flow = _CountingAppFlowController();
        final container = await pumpPatterns(
          tester,
          overrides: [appFlowProvider.overrideWith(() => flow)],
        );
        container.read(appFlowProvider.notifier).toProgression();
        await tester.pump();

        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
        expect(find.byTooltip('Back to Today'), findsNothing);
        expect(find.byTooltip('Back to Insights'), findsNothing);
        expect(find.bySemanticsLabel('Back to Today'), findsNothing);

        // The title is a heading, not a control.
        final title = tester.getSemantics(_title('Insights'));
        expect(
          title.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(title.getSemanticsData().flagsCollection.isHeader, isTrue);
        final share = tester.getSemantics(find.byTooltip('Share progress'));
        expect(share.id, isNot(title.id));
        expect(share.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        // Patterns is the selected part of the switch.
        final selected = tester
            .getSemantics(
              find
                  .descendant(
                    of: find.byKey(InsightsDestinationSwitch.switchKey),
                    matching: find.bySemanticsLabel('Patterns'),
                  )
                  .last,
            )
            .getSemanticsData();
        expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);

        await tester.tap(
          find.descendant(
            of: find.byKey(InsightsDestinationSwitch.switchKey),
            matching: find.text('Future outcomes'),
          ),
        );
        await tester.pump();
        expect(container.read(appFlowProvider), AppView.trajectoryEngine);
        expect(flow.todayCalls, 0);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('the share menu opens and shares the achievement too', (
    tester,
  ) async {
    String? clipboardText;
    _mockShareUnavailable(tester, (String? text) => clipboardText = text);
    await pumpPatterns(tester);

    final Finder share = find.byTooltip('Share progress');
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Progress snapshot'), findsOneWidget);
    await tester.tap(find.text('Achievement'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Review achievement snapshot'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'Share sheet unavailable. Achievement summary copied to clipboard.',
      ),
      findsOneWidget,
    );
    expect(clipboardText, contains('Axiomara progress milestone'));
    expect(clipboardText, isNot(contains('Momentum')));
    expect(clipboardText, isNot(contains('Pace')));
  });

  testWidgets(
    'share progress falls back to clipboard + SnackBar when the share sheet is unavailable',
    (WidgetTester tester) async {
      String? clipboardText;
      _mockShareUnavailable(tester, (String? text) => clipboardText = text);
      await pumpPatterns(tester);

      final Finder share = find.byTooltip('Share progress');
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Progress snapshot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Review progress snapshot'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Share sheet unavailable. Progress snapshot copied to clipboard.',
        ),
        findsOneWidget,
      );
      expect(clipboardText, contains('Axiomara progress snapshot'));
      expect(clipboardText, contains('Level'));
      expect(clipboardText, contains('tasks finished'));
      // The learned pace score is shown nowhere in the app: not shared.
      expect(clipboardText, isNot(contains('Pace')));
    },
  );
}

/// Neither share_plus's platform channel nor the clipboard channel has a real
/// implementation under flutter_test (an unmocked channel hangs rather than
/// throwing), so both are mocked: the share channel to simulate "no
/// implementation available", the clipboard channel to record what is set.
void _mockShareUnavailable(
  WidgetTester tester,
  void Function(String? text) onClipboard,
) {
  String? clipboardText;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (
    MethodCall call,
  ) async {
    switch (call.method) {
      case 'Clipboard.setData':
        clipboardText =
            (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        onClipboard(clipboardText);
        return null;
      case 'Clipboard.getData':
        return <String, dynamic>{'text': clipboardText};
      default:
        return null;
    }
  });
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (MethodCall call) async {
      throw PlatformException(
        code: 'unavailable',
        message: 'no share implementation in tests',
      );
    },
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
  });
}

class _CountingAppFlowController extends AppFlowController {
  int todayCalls = 0;

  @override
  void show(AppView view) {
    if (view == AppView.nexus) todayCalls++;
    super.show(view);
  }
}
