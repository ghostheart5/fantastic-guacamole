import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final formField in [false, true]) {
    for (final key in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      testWidgets(
        '${formField ? 'form field' : 'button'} ignores repeated ${key.keyLabel} during menu opening and keeps selection working',
        (tester) async {
          final navigator = GlobalKey<NavigatorState>();
          final focus = FocusNode();
          addTearDown(focus.dispose);
          int selected = 1;
          int changes = 0;
          const items = [
            DropdownMenuItem(value: 1, child: Text('One')),
            DropdownMenuItem(value: 2, child: Text('Two')),
          ];
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    void onChanged(int? value) {
                      setState(() {
                        selected = value!;
                        changes++;
                      });
                    }

                    return DropdownRouteKeyboardGuard(
                      child: formField
                          ? DropdownButtonFormField<int>(
                              focusNode: focus,
                              autofocus: true,
                              initialValue: selected,
                              items: items,
                              onChanged: onChanged,
                            )
                          : DropdownButton<int>(
                              focusNode: focus,
                              autofocus: true,
                              value: selected,
                              items: items,
                              onChanged: onChanged,
                            ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isTrue);
          await tester.sendKeyDownEvent(key);
          await tester.sendKeyRepeatEvent(key);
          await tester.sendKeyUpEvent(key);
          expect(tester.takeException(), isNull);
          expect(navigator.currentState!.canPop(), isTrue);
          expect(changes, 0);
          await tester.pumpAndSettle();

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(selected, 2);
          expect(changes, 1);
          expect(navigator.currentState!.canPop(), isFalse);
          expect(tester.takeException(), isNull);

          // A later pointer opening and cancellation still work after focus
          // returns from the dismissed menu.
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pumpAndSettle();
          expect(navigator.currentState!.canPop(), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(navigator.currentState!.canPop(), isFalse);
          expect(selected, 2);
          expect(changes, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
