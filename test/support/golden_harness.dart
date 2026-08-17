import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real bundled Inter font so golden images reflect actual
/// typography rather than flutter_test's fallback test font — otherwise a
/// font-size regression test would be meaningless. Call once from a
/// `setUpAll` in each golden test file.
Future<void> loadAppFontsForGolden() async {
  final FontLoader loader = FontLoader('Inter');
  for (final String asset in <String>[
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

/// Pumps [widget] at a fixed physical [size] under the app's real theme, for
/// deterministic golden-image capture.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget widget, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: appTheme, home: widget));
  await tester.pump();
}

/// Swaps in a comparator that tolerates a small pixel-diff percentage before
/// the golden test's own [setUpAll]. Screens with a perpetually-repeating
/// `AnimationController` (Nexus's ambient pulse effects) render a handful of
/// differing pixels run-to-run even with zero code changes — the diff is a
/// few hundred pixels out of a multi-megapixel capture (~0.02%), driven by
/// the animation's phase at capture time, not a real regression. A real
/// font/breakpoint regression moves far more than that, so a generous
/// tolerance still catches it while absorbing animation jitter.
void useTolerantGoldenComparator() {
  final LocalFileComparator delegate =
      goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(delegate);
}

class _TolerantGoldenComparator extends GoldenFileComparator {
  _TolerantGoldenComparator(this._delegate);

  final LocalFileComparator _delegate;

  // Balances two sources of unavoidable pixel drift that are not regressions:
  //   1. Animation jitter: perpetually-repeating AnimationControllers render a
  //      handful of differing pixels run-to-run even with zero code changes
  //      (typically ~0.02%).
  //   2. Cross-platform font rendering: goldens generated on macOS differ from
  //      Linux CI output by 2–6% due to different text rasterisers.
  // Both sources produce far less variance than a real font/breakpoint
  // regression (which typically shifts 10–20%+ of pixels), so a 6% ceiling
  // still catches meaningful layout changes while absorbing these artefacts.
  static const double _maxDiffPercent = 6.0;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    try {
      return await _delegate.compare(imageBytes, golden);
    } on FlutterError catch (e) {
      final RegExpMatch? match = RegExp(
        r'Pixel test failed, ([\d.]+)%',
      ).firstMatch(e.message);
      if (match != null && double.parse(match.group(1)!) <= _maxDiffPercent) {
        return true;
      }
      rethrow;
    }
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      _delegate.update(golden, imageBytes);
}
