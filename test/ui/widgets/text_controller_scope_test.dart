import 'package:fantastic_guacamole/ui/widgets/text_controller_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'two-field dialog preserves drafts through rebuild and disposes after exit',
    (WidgetTester tester) async {
      addTearDown(tester.view.resetViewInsets);
      late List<TextEditingController> owned;
      bool resultReturned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => TextControllerScope(
                      initialTexts: const <String>['Original value', ''],
                      builder: (context, controllers) {
                        owned = controllers;
                        return AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                key: const Key('value'),
                                controller: controllers[0],
                              ),
                              TextField(
                                key: const Key('reason'),
                                controller: controllers[1],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                  resultReturned = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('value')), 'Corrected draft');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'User correction',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(owned.map((controller) => controller.text), [
        'Corrected draft',
        'User correction',
      ]);

      await tester.binding.handlePopRoute();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 16));
      expect(resultReturned, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      for (final controller in owned) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
    },
  );
}
