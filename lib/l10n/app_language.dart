import 'dart:ui' show PlatformDispatcher;

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/widgets.dart';

/// Whether the app is showing Spanish, for text built without a widget
/// context (OS reminder titles and bodies).
///
/// The app sets no fixed locale: MaterialApp resolves the device languages
/// ([deviceLocales], by default the platform's) against
/// [ChronoSparkLocalizations.supportedLocales] with Flutter's
/// [basicLocaleListResolution], and every screen reads the result through
/// `Localizations.localeOf`. This makes the same decision, so the two agree.
bool appLanguageIsSpanish([List<Locale>? deviceLocales]) =>
    basicLocaleListResolution(
      deviceLocales ?? _deviceLocales(),
      ChronoSparkLocalizations.supportedLocales,
    ).languageCode ==
    'es';

/// The list MaterialApp reads, or the platform's before the app has started.
List<Locale> _deviceLocales() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locales;
  } on Object {
    // No binding yet.
  }
  try {
    return PlatformDispatcher.instance.locales;
  } on Object {
    // No platform locale: English, the app's fallback.
    return const <Locale>[];
  }
}
