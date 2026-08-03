import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings screen surfaces reminder and voice controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Daily Reflection'), findsOneWidget);
    expect(find.text('Reminder Automation'), findsOneWidget);
    expect(find.text('Voice Access'), findsOneWidget);
  });
}
