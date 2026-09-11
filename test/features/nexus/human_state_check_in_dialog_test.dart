import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/nexus/ui/human_state_check_in_dialog.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pumpDialog(
    WidgetTester tester, {
    bool energy = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('check-in-owner'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => HumanStateCheckInDialog(energy: energy),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'no invented default; explicit energy saves and clearing removes observation',
    (tester) async {
      final container = await pumpDialog(tester);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      tester.widget<Slider>(find.byType(Slider)).onChanged!(.8);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(container.read(siStateProvider).energy, .8);
      expect(container.read(siStateProvider).hasObservedEnergy, isTrue);
      expect(container.read(siStateProvider).hasObservedFatigue, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(container.read(siStateProvider).hasObservedEnergy, isFalse);
    },
  );

  testWidgets('fatigue is explicit and cancellation leaves state unchanged', (
    tester,
  ) async {
    final container = await pumpDialog(tester, energy: false);
    expect(find.textContaining('not a cognitive assessment'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(.7);
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(siStateProvider).hasObservedFatigue, isFalse);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(.7);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(siStateProvider).fatigue, .7);
      expect(container.read(siStateProvider).hasObservedFatigue, isTrue);
      expect(container.read(siStateProvider).hasObservedEnergy, isFalse);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
  });

  testWidgets('an account transition rejects a stale save callback', (
    tester,
  ) async {
    final container = await pumpDialog(tester);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(.8);
    await tester.pump();
    final staleSave = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
        .onPressed!;
    container
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: 'another-account', isTransitioning: true);
    staleSave();
    await tester.pump();
    expect(container.read(siStateProvider).hasObservedEnergy, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });
}
