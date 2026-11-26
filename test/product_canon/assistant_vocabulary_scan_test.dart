import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One vocabulary for the assistant: the feature is "Assistant" (Choose a step
/// and Chat together), its two modes are "On this device · free" and "AI chat",
/// and the destination screen is "Chat". Internal names must not reach a
/// person in English or Spanish.
///
/// This scans every quoted string in lib/ outside comments. Only the files and
/// messages listed below are exempt.
final RegExp _retired = RegExp(
  r'\bSI\b|Free tools|free tools|On-device tools|[Ee]xternal[- ]assistant|'
  r'[Ee]xternal AI|[Ee]xternal explanation|[Ee]xternal provider|'
  r'[Ee]xternal service|IA externa|asistente externo|servicio externo|'
  r'proveedor externo|explicaci[oó]n externa|[Cc]loud AI|[Cc]loud questions?|'
  r'IA en la nube|Herramientas gratis|Herramientas locales|'
  r'asistencia de IA externa',
);
final RegExp _quoted = RegExp(r"""(['"])((?:\\.|(?!\1).)*)\1""");

/// Files whose strings are exception messages, log lines, storage inventory
/// or protocol identifiers, never shown to a person.
const Set<String> _exemptFiles = <String>{
  'lib/domain/entities/assistant_contracts.dart',
  'lib/domain/assistant/axiomara_router_contract.dart',
  'lib/core/data/account_data_registry.dart',
  'lib/data/services/workspace_store_service.dart',
  'lib/data/repositories/si_engine_repository.dart',
  'lib/config/public_release_profile.dart',
};

/// Single internal messages in otherwise visible files.
const Set<String> _internalMessages = <String>{
  ' skipped. SI will adapt the next pick.',
  'SI display boundary rejected a response from another runtime.',
  'SI Console must show the dedicated crisis support route.',
  'SI Console must show the dedicated non-crisis support route.',
  'The SI response did not pass the safety boundary.',
  'SI V2 withheld a draft that could not be safely repaired into its typed contract.',
};

/// Spanish "SI" means "if" in these uppercase labels; a pattern is not copy.
bool _isNotCopy(String copy) =>
    copy.startsWith('SI ESPERAS') ||
    copy == 'SI SE APLAZA' ||
    copy.startsWith(r'^(?:SI|ASSISTANT)') ||
    copy.startsWith('SI shortcut ') ||
    copy.startsWith('Duplicate SI shortcut') ||
    copy.startsWith('Invalid SI shortcut') ||
    copy.startsWith('SI shortcut registry') ||
    // Exception messages of the SI V2 and intelligence-receipt contracts.
    copy.startsWith('SI V2 ') ||
    copy.startsWith('SI intelligence receipts ') ||
    copy.startsWith('SI confidence must ') ||
    copy.endsWith(' SI intelligence receipt version.') ||
    copy.endsWith(' SI intelligence receipt time.') ||
    // The safety policy's pattern for repairing a leading "SI" in replies.
    copy.startsWith(r'(^|(?<=[.!?])\s+)SI');

void main() {
  test('no visible text uses a retired assistant name', () {
    final List<String> violations = <String>[];
    for (final File file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))) {
      final String path = file.path.replaceAll(r'\', '/');
      if (_exemptFiles.contains(path)) continue;
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String trimmed = lines[i].trimLeft();
        if (trimmed.startsWith(RegExp(r'(import|export|part|//|\*)'))) {
          continue;
        }
        for (final RegExpMatch match in _quoted.allMatches(lines[i])) {
          final String copy = match.group(2)!;
          if (_isNotCopy(copy) || _internalMessages.contains(copy)) continue;
          if (_retired.hasMatch(copy)) {
            violations.add('$path:${i + 1}: $copy');
          }
        }
      }
    }
    // Triple-quoted strings can span lines, so scan whole files for them.
    final RegExp triple = RegExp(
      r"'''[\s\S]*?'''|"
      r'"""[\s\S]*?"""',
    );
    for (final File file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))) {
      final String path = file.path.replaceAll(r'\', '/');
      if (_exemptFiles.contains(path)) continue;
      for (final RegExpMatch match in triple.allMatches(
        file.readAsStringSync(),
      )) {
        if (_retired.hasMatch(match.group(0)!)) {
          violations.add('$path: triple-quoted copy ${match.group(0)}');
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
