import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color text, Color surface) {
  final visible = Color.alphaBlend(text, surface).computeLuminance();
  final background = surface.computeLuminance();
  return visible > background
      ? (visible + .05) / (background + .05)
      : (background + .05) / (visible + .05);
}

void main() {
  for (final dark in [true, false]) {
    testWidgets(
      'rendered forms remain readable over dark artwork, dark=$dark',
      (tester) async {
        final theme = dark ? appTheme : appLightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: AnimatedSystemBackground(
              animate: false,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    const TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    FilledButton(onPressed: () {}, child: const Text('Save')),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Choose'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final input = tester.widget<EditableText>(find.byType(EditableText));
        final decoration = tester.widget<InputDecorator>(
          find.byType(InputDecorator),
        );
        final fill = Color.alphaBlend(
          decoration.decoration.fillColor!,
          AppColors.background,
        );
        expect(_contrast(input.style.color!, fill), greaterThanOrEqualTo(4.5));

        for (final entry in [
          ('Cancel', theme.textButtonTheme.style),
          ('Save', theme.filledButtonTheme.style),
          ('Choose', theme.outlinedButtonTheme.style),
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(entry.$1),
          );
          final textColor = paragraph.text.style!.color!;
          final buttonFill =
              entry.$2?.backgroundColor?.resolve({}) ??
              (entry.$1 == 'Save'
                  ? theme.colorScheme.primary
                  : AppColors.background);
          final surface = Color.alphaBlend(buttonFill, AppColors.background);
          expect(
            _contrast(textColor, surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.$1} must remain readable in this appearance',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
