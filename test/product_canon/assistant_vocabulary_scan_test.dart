import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One vocabulary for the assistant: the feature is "Assistant", its two modes
/// are "On this device · free" and "AI chat". Internal names (SI, SI Console,
/// "external AI", "cloud AI", "free tools", "on-device tools") must not reach
/// a person in English or Spanish.
///
/// This is a source scan of visible copy. Exception messages thrown between
/// layers, code identifiers, route names and test keys are not visible copy.
final RegExp _retired = RegExp(
  r'\bSI\b|\bSI Chat\b|\bChat SI\b|Free tools|free tools|On-device tools|'
  r'External AI|external AI|IA externa|[Cc]loud AI|IA en la nube|'
  r'Herramientas gratis|Herramientas locales|asistencia de IA externa',
);
final RegExp _quoted = RegExp(r"""(['"])((?:\.|(?!\1).)*)\1""");

const List<String> _roots = <String>[
  'lib/features',
  'lib/l10n',
  'lib/tutorial',
  'lib/ui/widgets',
  'lib/engine/si',
  'lib/state/providers',
  'lib/state/controllers',
  'lib/domain/strategic/si_console_shortcut_registry.dart',
  'lib/domain/entities/memory_entity.dart',
];

/// Spanish "SI" means "if" in these uppercase labels; a pattern is not copy.
bool _isNotCopy(String copy) =>
    copy.startsWith('SI ESPERAS') ||
    copy == 'SI SE APLAZA' ||
    copy.startsWith(r'^(?:SI|ASSISTANT)');

/// Messages that travel between layers inside exceptions and evidence ids.
const Set<String> _internalMessages = <String>{
  'SI display boundary rejected a response from another runtime.',
  'SI Console must show the dedicated crisis support route.',
  'SI Console must show the dedicated non-crisis support route.',
  'The SI response did not pass the safety boundary.',
  'SI V2 withheld a draft that could not be safely repaired into its typed contract.',
};

void main() {
  test('no visible text uses a retired assistant name', () {
    final List<String> violations = <String>[];
    for (final String root in _roots) {
      final List<File> files = root.endsWith('.dart')
          ? <File>[File(root)]
          : Directory(root)
                .listSync(recursive: true)
                .whereType<File>()
                .where((File f) => f.path.endsWith('.dart'))
                .toList();
      for (final File file in files) {
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          final String trimmed = line.trimLeft();
          if (trimmed.startsWith(RegExp(r'(import|export|part|//)'))) continue;
          final String nearby = lines
              .sublist(i < 3 ? 0 : i - 3, i + 1)
              .join('\n');
          if (RegExp(r'throw |Exception\(|Error\(').hasMatch(nearby)) continue;
          for (final RegExpMatch match in _quoted.allMatches(line)) {
            final String copy = match.group(2)!;
            if (_isNotCopy(copy) || _internalMessages.contains(copy)) continue;
            if (_retired.hasMatch(copy)) {
              violations.add('${file.path}:${i + 1}: $copy');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the new vocabulary is present in both languages', () {
    final String modeSwitch = File(
      'lib/features/assistant/ui/assistant_mode_switch.dart',
    ).readAsStringSync();
    expect(modeSwitch, contains("'On this device · free'"));
    expect(modeSwitch, contains("'En este dispositivo · gratis'"));
    final String today = File(
      'lib/features/home/ui/today_screen.dart',
    ).readAsStringSync();
    expect(
      today,
      contains('The Assistant helps with your thoughts and plans.'),
    );
    expect(today, contains('El asistente te ayuda con tus ideas y planes.'));
  });
}
