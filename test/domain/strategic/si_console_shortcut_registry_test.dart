import 'dart:io';

import 'package:fantastic_guacamole/domain/strategic/si_console_shortcut_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIConsoleShortcutRegistry', () {
    test('registry is internally valid and owns every unique token', () {
      expect(SIConsoleShortcutRegistry.validate, returnsNormally);

      final Set<String> tokens = <String>{};
      for (final SIConsoleShortcutDefinition definition
          in SIConsoleShortcutRegistry.definitions) {
        for (final String token in definition.tokens) {
          expect(tokens.add(token.toLowerCase()), isTrue, reason: token);
        }
      }
    });

    test('parser recognizes every primary shortcut and alias', () {
      for (final SIConsoleShortcutDefinition definition
          in SIConsoleShortcutRegistry.definitions) {
        for (final String token in definition.tokens) {
          final SIConsoleShortcutInvocation invocation =
              SIConsoleShortcutRegistry.parse(token.toUpperCase());
          expect(
            invocation.kind,
            SIShortcutParseKind.recognized,
            reason: token,
          );
          expect(invocation.definition, same(definition), reason: token);
          expect(invocation.arguments, isEmpty, reason: token);
        }
      }
    });

    test('every forwarded argument is preserved and never silently lost', () {
      const String argument = 'Keep THIS exact  argument /with-slash';
      final Iterable<SIConsoleShortcutDefinition> forwarded =
          SIConsoleShortcutRegistry.definitions.where(
            (SIConsoleShortcutDefinition item) =>
                item.argumentPolicy ==
                SIShortcutArgumentPolicy.forwardToIntelligence,
          );

      for (final SIConsoleShortcutDefinition definition in forwarded) {
        final SIConsoleShortcutInvocation invocation =
            SIConsoleShortcutRegistry.parse(
              '${definition.shortcut}   $argument',
            );
        expect(invocation.arguments, argument, reason: definition.shortcut);
        expect(
          invocation.intelligenceInput,
          argument,
          reason: definition.shortcut,
        );
        expect(
          invocation.forcedSurface,
          definition.surface,
          reason: definition.shortcut,
        );
        expect(
          invocation.resolvedRoute,
          SIShortcutRoute.intelligenceQuery,
          reason: definition.shortcut,
        );
      }
    });

    test('no-argument evidence shortcuts retain their registered route', () {
      final Iterable<SIConsoleShortcutDefinition> snapshots =
          SIConsoleShortcutRegistry.definitions.where(
            (SIConsoleShortcutDefinition item) =>
                item.route.name.endsWith('Snapshot'),
          );
      for (final SIConsoleShortcutDefinition definition in snapshots) {
        final SIConsoleShortcutInvocation invocation =
            SIConsoleShortcutRegistry.parse(definition.shortcut);
        expect(
          invocation.resolvedRoute,
          definition.route,
          reason: definition.shortcut,
        );
        expect(
          invocation.intelligenceInput,
          definition.surface,
          reason: definition.shortcut,
        );
      }
    });

    test('help, chips, and autocomplete have full registry parity', () {
      final String help = SIConsoleShortcutRegistry.buildHelp();
      for (final SIConsoleShortcutDefinition definition
          in SIConsoleShortcutRegistry.definitions) {
        expect(help, contains(definition.usage), reason: definition.shortcut);
        expect(
          SIConsoleShortcutRegistry.autocomplete(definition.shortcut),
          contains(same(definition)),
          reason: definition.shortcut,
        );
      }

      expect(
        SIConsoleShortcutRegistry.chips,
        orderedEquals(SIConsoleShortcutRegistry.definitions),
      );
    });

    test(
      'help filters consume their argument and status rejects its argument',
      () {
        final SIConsoleShortcutInvocation help =
            SIConsoleShortcutRegistry.parse('/help tasks');
        expect(help.arguments, 'tasks');
        expect(help.resolvedRoute, SIShortcutRoute.help);
        expect(
          SIConsoleShortcutRegistry.buildHelp(filter: help.arguments),
          allOf(contains('/tasks'), isNot(contains('/goals [question]'))),
        );

        final SIConsoleShortcutInvocation status =
            SIConsoleShortcutRegistry.parse('/status tasks');
        expect(status.arguments, 'tasks');
        expect(status.argumentsRejected, isTrue);
        expect(status.resolvedRoute, SIShortcutRoute.status);
      },
    );

    test(
      'unknown slash input and ordinary free text remain distinguishable',
      () {
        final SIConsoleShortcutInvocation unknown =
            SIConsoleShortcutRegistry.parse('/not-real preserve this');
        expect(unknown.kind, SIShortcutParseKind.unknown);
        expect(unknown.token, '/not-real');
        expect(unknown.arguments, 'preserve this');

        final SIConsoleShortcutInvocation freeText =
            SIConsoleShortcutRegistry.parse('what needs attention?');
        expect(freeText.kind, SIShortcutParseKind.notShortcut);
        expect(freeText.rawInput, 'what needs attention?');

        final SIConsoleShortcutInvocation conversationalHelp =
            SIConsoleShortcutRegistry.parse('help me decide what matters');
        expect(conversationalHelp.kind, SIShortcutParseKind.notShortcut);
        expect(conversationalHelp.rawInput, 'help me decide what matters');
      },
    );

    test(
      'production parser, chips, help, autocomplete, and AI use the registry',
      () {
        final String screen = <String>[
          'lib/features/si_console/ui/si_console_screen.dart',
          'lib/features/si_console/ui/si_console_screen.widgets.dart',
        ].map((String path) => File(path).readAsStringSync()).join('\n');
        final String controller = File(
          'lib/state/controllers/ai_controller.dart',
        ).readAsStringSync();

        expect(screen, contains('SIConsoleShortcutRegistry.parse(text)'));
        expect(screen, contains('SIConsoleShortcutRegistry.chips'));
        expect(screen, contains('SIConsoleShortcutRegistry.buildHelp'));
        expect(screen, contains('SIConsoleShortcutRegistry.autocomplete'));
        expect(
          controller,
          contains('SIConsoleShortcutRegistry.parse(rawInput)'),
        );
        expect(controller, isNot(contains("'/xp': 'progression'")));
        expect(controller, isNot(contains('_stripLeadingSurfaceCommand')));
      },
    );
  });
}
