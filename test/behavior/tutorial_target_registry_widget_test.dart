import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';

void main() {
  group('TutorialTargetRegistry widget behavior', () {
    testWidgets('TutorialTarget registers a render rect after pump', (tester) async {
      const targetId = 'test.nexus.action_hub';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TutorialTarget(
                id: targetId,
                child: SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final rect = TutorialTargetRegistry.instance.rectFor(targetId);

      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    testWidgets('changing target id unregisters old id and registers new id', (
      tester,
    ) async {
      const oldId = 'test.target.old';
      const newId = 'test.target.new';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorialTarget(
              id: oldId,
              child: SizedBox(width: 60, height: 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(TutorialTargetRegistry.instance.rectFor(oldId), isNotNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorialTarget(
              id: newId,
              child: SizedBox(width: 60, height: 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(TutorialTargetRegistry.instance.rectFor(oldId), isNull);
      final Rect? newRect = TutorialTargetRegistry.instance.rectFor(newId);
      expect(newRect, isNotNull);
      expect(newRect!.width, greaterThan(0));
      expect(newRect.height, greaterThan(0));
    });

    testWidgets('TutorialTarget unregisters when removed from tree', (tester) async {
      const targetId = 'test.creator.button';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorialTarget(
              id: targetId,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(TutorialTargetRegistry.instance.rectFor(targetId), isNotNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(TutorialTargetRegistry.instance.rectFor(targetId), isNull);
    });
  });
}
