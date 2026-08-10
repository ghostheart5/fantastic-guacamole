import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _flutterTtsChannel = MethodChannel('flutter_tts');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_flutterTtsChannel, (MethodCall call) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_flutterTtsChannel, null);
  });

  group('si console input accessibility', () {
    testWidgets('submitting via keyboard enter posts user text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extendedDomainBootstrapProvider.overrideWith((Ref ref) async {}),
            executionSignalsProvider.overrideWith(
              (Ref ref) => const ExecutionSignals(
                createdToday: 0,
                completedToday: 2,
                skippedToday: 0,
                delayedToday: 0,
                created7d: 0,
                completed7d: 7,
                skipped7d: 1,
                delayed7d: 1,
              ),
            ),
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 68,
                trend: 'Rising',
                recovery: 'Recovered',
                forecast: 'Consistency will increase output quality.',
                energyPercent: 64,
                pressurePercent: 35,
                streak: 4,
                completedToday: 2,
              ),
            ),
          ],
          child: const MaterialApp(home: SIConsoleScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsIdentifier('screen-si-console'), findsOneWidget);
      expect(find.bySemanticsIdentifier('si-console-input'), findsOneWidget);
      expect(find.bySemanticsIdentifier('si-console-send'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'status check');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('status check'), findsOneWidget);
    });

    testWidgets('help command exposes a stable response semantic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extendedDomainBootstrapProvider.overrideWith((Ref ref) async {}),
            executionSignalsProvider.overrideWith(
              (Ref ref) => const ExecutionSignals(
                createdToday: 0,
                completedToday: 0,
                skippedToday: 0,
                delayedToday: 0,
                created7d: 0,
                completed7d: 0,
                skipped7d: 0,
                delayed7d: 0,
              ),
            ),
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 0,
                trend: 'Stable',
                recovery: 'Stable',
                forecast: 'No forecast yet.',
                energyPercent: 50,
                pressurePercent: 0,
                streak: 0,
                completedToday: 0,
              ),
            ),
          ],
          child: const MaterialApp(home: SIConsoleScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), '/help');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('si-console-guide-response'),
        findsOneWidget,
      );
    });

    testWidgets('daily command chip is visible and can be triggered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extendedDomainBootstrapProvider.overrideWith((Ref ref) async {}),
            executionSignalsProvider.overrideWith(
              (Ref ref) => const ExecutionSignals(
                createdToday: 0,
                completedToday: 2,
                skippedToday: 1,
                delayedToday: 0,
                created7d: 0,
                completed7d: 7,
                skipped7d: 1,
                delayed7d: 1,
              ),
            ),
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 68,
                trend: 'Rising',
                recovery: 'Recovered',
                forecast: 'Consistency will increase output quality.',
                energyPercent: 64,
                pressurePercent: 35,
                streak: 4,
                completedToday: 2,
              ),
            ),
          ],
          child: const MaterialApp(home: SIConsoleScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('/daily'), findsOneWidget);
      await tester.tap(find.text('/daily'));
      await tester.pump();

      expect(find.text('/daily'), findsWidgets);
    });
  });
}
