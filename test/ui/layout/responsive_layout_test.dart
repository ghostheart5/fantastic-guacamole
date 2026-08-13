import 'package:fantastic_guacamole/ui/layout/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the compact mobile rules below 600', (tester) async {
    final probe = await _probeViewport(tester, const Size(599, 800));

    expect(probe.isCompact, isTrue);
    expect(probe.padding, const EdgeInsets.symmetric(horizontal: 16, vertical: 20));
    expect(probe.contentMaxWidth, double.infinity);
  });

  testWidgets('selects deterministic rules at the 600 boundary', (tester) async {
    final probe = await _probeViewport(tester, const Size(600, 800));

    expect(probe.isCompact, isFalse);
    expect(probe.padding, const EdgeInsets.symmetric(horizontal: 24, vertical: 20));
    expect(probe.contentMaxWidth, double.infinity);
  });

  testWidgets('selects tablet rules at the 840 boundary', (tester) async {
    final beforeTablet = await _probeViewport(tester, const Size(839, 800));
    final tablet = await _probeViewport(tester, const Size(840, 800));

    expect(beforeTablet.padding.horizontal, 48);
    expect(beforeTablet.contentMaxWidth, double.infinity);
    expect(tablet.padding, const EdgeInsets.symmetric(horizontal: 32, vertical: 20));
    expect(tablet.contentMaxWidth, 920);
  });

  testWidgets('selects desktop content width at the 1200 boundary', (tester) async {
    final beforeDesktop = await _probeViewport(tester, const Size(1199, 800));
    final desktop = await _probeViewport(tester, const Size(1200, 800));

    expect(beforeDesktop.contentMaxWidth, 920);
    expect(desktop.contentMaxWidth, 1120);
  });

  testWidgets('uses compact-height page padding below 480', (tester) async {
    final compactHeight = await _probeViewport(tester, const Size(500, 479));
    final standardHeight = await _probeViewport(tester, const Size(500, 480));

    expect(compactHeight.isCompactHeight, isTrue);
    expect(compactHeight.padding, const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    expect(standardHeight.isCompactHeight, isFalse);
    expect(standardHeight.padding, const EdgeInsets.symmetric(horizontal: 16, vertical: 20));
  });

  testWidgets('ResponsiveContent applies responsive width and default alignment',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(1200, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ResponsiveContent(child: SizedBox()),
        ),
      ),
    );

    final alignment = tester.widget<Align>(find.byType(Align));
    final constrainedBox = tester.widget<ConstrainedBox>(find.byType(ConstrainedBox));

    expect(alignment.alignment, Alignment.topCenter);
    expect(constrainedBox.constraints.maxWidth, 1120);
  });

  testWidgets('ResponsiveContent preserves explicit width and alignment',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(400, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ResponsiveContent(
            maxWidth: 320,
            alignment: Alignment.centerLeft,
            child: SizedBox(),
          ),
        ),
      ),
    );

    final alignment = tester.widget<Align>(find.byType(Align));
    final constrainedBox = tester.widget<ConstrainedBox>(find.byType(ConstrainedBox));

    expect(alignment.alignment, Alignment.centerLeft);
    expect(constrainedBox.constraints.maxWidth, 320);
  });
}

Future<_ViewportProbe> _probeViewport(WidgetTester tester, Size size) async {
  late _ViewportProbe probe;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(
        builder: (context) {
          probe = _ViewportProbe(
            isCompact: AppViewport.isCompact(context),
            isCompactHeight: AppViewport.isCompactHeight(context),
            padding: AppViewport.pagePadding(context),
            contentMaxWidth: AppViewport.contentMaxWidth(context),
          );
          return const SizedBox();
        },
      ),
    ),
  );

  return probe;
}

class _ViewportProbe {
  const _ViewportProbe({
    required this.isCompact,
    required this.isCompactHeight,
    required this.padding,
    required this.contentMaxWidth,
  });

  final bool isCompact;
  final bool isCompactHeight;
  final EdgeInsets padding;
  final double contentMaxWidth;
}
