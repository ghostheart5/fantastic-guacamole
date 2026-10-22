import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Scrolling header keeps Back, title and Settings independent', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int backCalls = 0;
    int settingsCalls = 0;
    try {
      await tester.pumpWidget(
        _headerHost(
          onBack: () => backCalls++,
          onOpenSettings: () => settingsCalls++,
        ),
      );

      final Finder back = find.bySemanticsLabel('Back to Today');
      expect(back, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(back);
      final SemanticsData backData = node.getSemanticsData();
      expect(backData.label, 'Back to Today');
      expect(backData.flagsCollection.isButton, isTrue);
      expect(backData.hasAction(SemanticsAction.tap), isTrue);
      expect(node.rect.size, const Size(48, 48));
      expect(node.rect.size, tester.getSize(find.byTooltip('Back to Today')));
      expect(
        tester.getSize(find.byType(TemporalScreenHeader)).width,
        greaterThan(node.rect.width),
      );
      expect(
        tester.getSize(find.byType(TemporalScreenHeader)).height,
        greaterThan(node.rect.height),
      );

      final SemanticsNode title = tester.getSemantics(find.text('Profile'));
      expect(title.id, isNot(node.id));
      expect(title.getSemanticsData().label, contains('Profile'));
      expect(title.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      final SemanticsNode settings = tester.getSemantics(
        find.byTooltip('Open settings'),
      );
      expect(settings.id, isNot(node.id));
      expect(settings.id, isNot(title.id));
      expect(settings.getSemanticsData().label, 'Open settings');
      expect(settings.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        settings.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(backCalls, 1);
      expect(settingsCalls, 0);
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
        settings.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(backCalls, 1);
      expect(settingsCalls, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Back pointer tap still invokes the callback exactly once', (
    WidgetTester tester,
  ) async {
    int backCalls = 0;
    int settingsCalls = 0;
    await tester.pumpWidget(
      _headerHost(
        onBack: () => backCalls++,
        onOpenSettings: () => settingsCalls++,
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();

    expect(backCalls, 1);
    expect(settingsCalls, 0);
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pump();
    expect(backCalls, 1);
    expect(settingsCalls, 1);
  });

  testWidgets('No Back node or pointer control exists without a callback', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_headerHost());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to Today'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}

Widget _headerHost({
  VoidCallback? onBack,
  VoidCallback? onOpenSettings,
}) => MaterialApp(
  theme: appTheme,
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        TemporalScreenHeader(
          title: 'Profile',
          eyebrow: 'About you',
          subtitle:
              'Review your name and recorded activity. You can edit your name here.',
          backTooltip: 'Back to Today',
          onBack: onBack,
          trailing: onOpenSettings == null
              ? null
              : IconButton(
                  tooltip: 'Open settings',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
        ),
        const SizedBox(height: 1200),
      ],
    ),
  ),
);
