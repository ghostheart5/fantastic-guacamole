import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/domain/strategic/si_console_shortcut_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Spanish are advertised release locales', () {
    expect(ChronoSparkLocalizations.supportedLocales, const <Locale>[
      Locale('en'),
      Locale('es'),
    ]);
  });

  test('every declared product string has English and Spanish text', () {
    const ChronoSparkLocalizations english = ChronoSparkLocalizations(
      Locale('en'),
    );
    const ChronoSparkLocalizations spanish = ChronoSparkLocalizations(
      Locale('es'),
    );

    for (final ChronoSparkString key in ChronoSparkString.values) {
      expect(
        english.text(key).trim(),
        isNotEmpty,
        reason: 'English ${key.name}',
      );
      expect(
        spanish.text(key).trim(),
        isNotEmpty,
        reason: 'Spanish ${key.name}',
      );
      expect(english.text(key), isNot(key.name), reason: 'English ${key.name}');
      expect(spanish.text(key), isNot(key.name), reason: 'Spanish ${key.name}');
    }
  });

  test('contextual guidance has Spanish title body and action coverage', () {
    const ChronoSparkLocalizations spanish = ChronoSparkLocalizations(
      Locale('es'),
    );
    for (final String id in <String>[
      'createFirstItem',
      'scheduleFirstItem',
      'reviewTimeline',
      'nexus',
      'smartPlanner',
      'timelineExecution',
      'siConsole',
      'trajectoryEngine',
      'progression',
    ]) {
      expect(spanish.guideTitle(id, 'fallback'), isNot('fallback'));
      expect(spanish.guideBody(id, 'fallback'), isNot('fallback'));
      expect(spanish.guideAction(id, 'fallback'), isNot('fallback'));
    }
  });

  test('Planner and SI routine copy is locale aware and typed', () {
    const ChronoSparkLocalizations english = ChronoSparkLocalizations(
      Locale('en'),
    );
    const ChronoSparkLocalizations spanish = ChronoSparkLocalizations(
      Locale('es'),
    );

    expect(
      spanish.plannerRoutine.guidanceUnavailable,
      isNot(english.plannerRoutine.guidanceUnavailable),
    );
    expect(spanish.plannerRoutine.voiceSummaryTitle, contains('Planificador'));
    expect(spanish.siRoutine.accessCheckFailed, contains('Consola SI'));
    expect(
      spanish.siRoutine.responseValidationFailed,
      contains('No se cambió'),
    );
    expect(
      spanish.siRoutine.shortcutHelp(filter: ''),
      contains('Atajos disponibles'),
    );

    for (final SIConsoleShortcutDefinition definition
        in SIConsoleShortcutRegistry.definitions) {
      expect(spanish.siRoutine.shortcutLabel(definition).trim(), isNotEmpty);
      expect(
        spanish.siRoutine.shortcutDescription(definition),
        isNot(definition.description),
        reason: definition.id,
      );
    }
  });
}
