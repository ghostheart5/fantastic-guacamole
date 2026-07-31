import 'package:fantastic_guacamole/features/creator/widgets/type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    testWidgets('hides Routine when legacy entry points are disabled', (
      WidgetTester tester,
    ) async {
      await dotenv.testLoad(fileInput: '''
CHRONOSPARK_ENABLE_LEGACY_ROUTINE_ENTRY_POINTS=false
''');

      await pumpSelector(tester);

      expect(find.text('HABIT'), findsOneWidget);
      expect(find.text('ROUTINE'), findsNothing);
    });

    testWidgets('shows Routine when legacy entry points are enabled', (
      WidgetTester tester,
    ) async {
      await dotenv.testLoad(fileInput: '''
CHRONOSPARK_ENABLE_LEGACY_ROUTINE_ENTRY_POINTS=true
''');

      await pumpSelector(tester);

      expect(find.text('HABIT'), findsOneWidget);
      expect(find.text('ROUTINE'), findsOneWidget);
    });
  });
}
