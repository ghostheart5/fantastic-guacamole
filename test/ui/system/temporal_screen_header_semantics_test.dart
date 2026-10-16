import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back semantic tap invokes the callback exactly once', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    int backCalls = 0;
    await tester.pumpWidget(_headerHost(onBack: () => backCalls++));

    final Finder back = find.bySemanticsLabel('Back to Nexus');
    expect(back, findsOneWidget);
    final SemanticsNode node = tester.getSemantics(back);
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pump();

    expect(backCalls, 1);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('Back pointer tap still invokes the callback exactly once', (
    WidgetTester tester,
  ) async {
    int backCalls = 0;
    await tester.pumpWidget(_headerHost(onBack: () => backCalls++));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();

    expect(backCalls, 1);
  });

  testWidgets('No Back node or pointer control exists without a callback', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(_headerHost());

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Nexus'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}

Widget _headerHost({VoidCallback? onBack}) => MaterialApp(
  home: Scaffold(
    body: TemporalScreenHeader(
      title: 'Timeline',
      subtitle: 'Review the current day.',
      backTooltip: 'Back to Nexus',
      onBack: onBack,
    ),
  ),
);
