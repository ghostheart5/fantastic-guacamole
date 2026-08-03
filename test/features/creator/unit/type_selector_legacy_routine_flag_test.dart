import 'dart:io';

import 'package:fantastic_guacamole/features/creator/widgets/type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypeSelector legacy routine flag', () {
    Future<void> pumpSelector(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypeSelector(
              selected: 'Task',
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('always renders DAILY RHYTHM type chip', (
      WidgetTester tester,
    ) async {
      await pumpSelector(tester);

      expect(find.text('DAILY RHYTHM'), findsOneWidget);
    });

    test('source keeps routine behind legacy-flag gate', () {
      final String source = File(
        'lib/features/creator/widgets/type_selector.dart',
      ).readAsStringSync();

      expect(source, contains('Env.enableLegacyRoutineEntryPoints'));
      expect(source, contains("values.add('Routine')"));
    });
  });
}
