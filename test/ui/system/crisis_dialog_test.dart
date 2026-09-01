import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resources use verified numbers only for known device regions', () {
    final SafetySupportResources us = SafetySupportResources.resolve(
      const Locale('en', 'US'),
    );
    final SafetySupportResources canada = SafetySupportResources.resolve(
      const Locale('en', 'CA'),
    );
    final SafetySupportResources spain = SafetySupportResources.resolve(
      const Locale('es', 'ES'),
    );
    final SafetySupportResources unknown = SafetySupportResources.resolve(
      const Locale('en'),
    );

    expect(us.crisisCallUri, Uri(scheme: 'tel', path: '988'));
    expect(us.crisisTextUri, Uri(scheme: 'sms', path: '988'));
    expect(us.emergencyCallUri, Uri(scheme: 'tel', path: '911'));
    expect(canada.crisisCallUri, Uri(scheme: 'tel', path: '988'));
    expect(canada.emergencyCallUri, Uri(scheme: 'tel', path: '911'));
    expect(spain.crisisCallUri, Uri(scheme: 'tel', path: '024'));
    expect(spain.crisisTextUri, isNull);
    expect(spain.emergencyCallUri, Uri(scheme: 'tel', path: '112'));
    expect(unknown.crisisCallUri, isNull);
    expect(unknown.crisisTextUri, isNull);
    expect(unknown.emergencyCallUri, isNull);
    expect(unknown.directoryUri.host, 'findahelpline.com');
  });

  testWidgets(
    'immediate safety route is localized and has no productivity action',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final List<Uri> opened = <Uri>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => FilledButton(
              onPressed: () => showCrisisDialog(
                context,
                locale: const Locale('es', 'ES'),
                launcher: (Uri uri) async {
                  opened.add(uri);
                  return true;
                },
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('immediate-safety-dialog')), findsOneWidget);
      expect(
        find.textContaining('no un juicio ni un diagnóstico'),
        findsOneWidget,
      );
      expect(find.text('Llamar a la Línea 024'), findsOneWidget);
      expect(find.text('Llamar al 112'), findsOneWidget);
      expect(find.byKey(const Key('safety-continue-gently')), findsNothing);

      await tester.tap(find.byKey(const Key('safety-call-crisis')));
      await tester.pumpAndSettle();
      expect(opened.single, Uri(scheme: 'tel', path: '024'));
    },
  );

  testWidgets('supportive route requires an explicit gentle continuation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SupportiveDistressChoice? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async {
              selected = await showSupportiveDistressDialog(
                context,
                locale: const Locale('en', 'US'),
                launcher: (Uri uri) async => true,
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('supportive-distress-dialog')), findsOneWidget);
    expect(find.textContaining('This is not a diagnosis'), findsOneWidget);
    expect(find.text('Continue with one gentle question'), findsOneWidget);
    expect(selected, isNull);

    await tester.tap(find.byKey(const Key('safety-continue-gently')));
    await tester.pumpAndSettle();
    expect(selected, SupportiveDistressChoice.continueWithGentleQuestion);
    expect(find.byKey(const Key('supportive-distress-dialog')), findsNothing);
  });

  testWidgets('failed support action remains visible and reports the failure', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => showCrisisDialog(
              context,
              locale: const Locale('en'),
              launcher: (Uri uri) async => false,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-find-local-support')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('immediate-safety-dialog')), findsOneWidget);
    expect(find.byKey(const Key('safety-action-error')), findsOneWidget);
  });
}
