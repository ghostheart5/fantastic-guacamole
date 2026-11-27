import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final double first = a.computeLuminance() + 0.05;
  final double second = b.computeLuminance() + 0.05;
  return first > second ? first / second : second / first;
}

BorderSide _segmentOutline(WidgetTester tester, String label) {
  final Material material = tester
      .widgetList<Material>(
        find.ancestor(of: find.text(label), matching: find.byType(Material)),
      )
      .firstWhere((Material widget) => widget.shape is RoundedRectangleBorder);
  return (material.shape! as RoundedRectangleBorder).side;
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    final ThemeData theme = ThemeData(brightness: brightness);
    final PlainPalette palette = PlainPalette.card(theme);

    testWidgets(
      'destination outline tracks keyboard focus in ${brightness.name}',
      (WidgetTester tester) async {
        final List<int> activated = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: DestinationSwitch(
                firstLabel: 'Patterns',
                secondLabel: 'Future outcomes',
                selectedIndex: 0,
                onSelected: activated.add,
              ),
            ),
          ),
        );

        expect(_segmentOutline(tester, 'Patterns').width, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final BorderSide focused = _segmentOutline(tester, 'Patterns');
        expect(focused.width, 3);
        expect(
          _contrast(focused.color, palette.selectedFill),
          greaterThanOrEqualTo(3),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_segmentOutline(tester, 'Patterns').width, 2);
        final BorderSide next = _segmentOutline(tester, 'Future outcomes');
        expect(next.width, 3);
        expect(_contrast(next.color, palette.fill), greaterThanOrEqualTo(3));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(activated, <int>[1]);
      },
    );

    testWidgets('range outline and keyboard activation in ${brightness.name}', (
      WidgetTester tester,
    ) async {
      final List<int> activated = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: RangeChoice(
              labels: const <String>['7 days', '30 days'],
              selectedIndex: 0,
              onSelected: activated.add,
            ),
          ),
        ),
      );

      final Iterable<ChoiceChip> chips = tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      );
      for (final ChoiceChip chip in chips) {
        final BorderSide? side = WidgetStateProperty.resolveAs<BorderSide?>(
          chip.side,
          <WidgetState>{WidgetState.focused},
        );
        expect(side?.width, 3);
        expect(
          _contrast(
            side!.color,
            chip.selected ? palette.selectedFill : palette.fill,
          ),
          greaterThanOrEqualTo(3),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, <int>[1]);
    });
  }
}
