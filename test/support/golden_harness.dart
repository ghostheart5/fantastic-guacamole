import 'dart:io';

import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's bundled Inter family and Flutter's Material icon font.
///
/// Golden images must not accept Ahem placeholder glyphs as visual evidence.
/// Call once from a `setUpAll` in each golden test file.
Future<void> loadAppFontsForGolden() async {
  final FontLoader interLoader = FontLoader('Inter');
  for (final String asset in <String>[
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]) {
    interLoader.addFont(rootBundle.load(asset));
  }
  await interLoader.load();

  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.trim().isEmpty) {
    throw StateError('FLUTTER_ROOT is required to load Material Icons.');
  }
  final File iconFont = File.fromUri(
    Uri.directory(
      flutterRoot,
    ).resolve('bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  );
  if (!iconFont.existsSync()) {
    throw StateError('Material icon font is missing: ${iconFont.path}');
  }
  final Uint8List iconBytes = await iconFont.readAsBytes();
  final FontLoader iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
  await iconLoader.load();
}

/// Returns the exact golden master for the host renderer running this test.
///
/// Windows and Linux rasterize the same bundled fonts differently. Keeping a
/// reviewed master for each supported host preserves pixel-for-pixel
/// comparison without hiding real drift behind a percentage tolerance.
String platformGoldenFile(String fileName) {
  final String platform;
  if (Platform.isWindows) {
    platform = 'windows';
  } else if (Platform.isLinux) {
    platform = 'linux';
  } else {
    throw UnsupportedError(
      'Golden comparisons are not configured for ${Platform.operatingSystem}.',
    );
  }
  return 'goldens/$platform/$fileName';
}

/// Pumps [widget] at a fixed physical [size] under the app's real theme, for
/// deterministic golden-image capture. Animations are disabled through the
/// same accessibility signal the production Nexus screen already honors.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget widget, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1,
          disableAnimations: true,
        ),
        child: widget,
      ),
    ),
  );
  await tester.pump();
}
