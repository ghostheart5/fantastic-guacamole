import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_commands.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_response_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI console command models', () {
    test('exposes stable slash command shortcuts without duplicates', () {
      final List<String> commands = SIConsoleCommands.values;

      expect(commands, isNotEmpty);
      expect(commands.toSet().length, commands.length);
      expect(commands.every((String c) => c.startsWith('/')), isTrue);
      expect(commands, contains('/help'));
      expect(commands, contains('/identity'));
      expect(commands, contains('/trajectory'));
    });

    test('rejects invalid placeholder SI responses', () {
      expect(SIConsoleResponseValidator.isInvalid('undefined'), isTrue);
      expect(SIConsoleResponseValidator.isInvalid(' null '), isTrue);
      expect(
        SIConsoleResponseValidator.isInvalid('Undefined Response'),
        isTrue,
      );
      expect(SIConsoleResponseValidator.isInvalid('no response'), isTrue);
    });

    test('accepts real non-placeholder SI responses', () {
      expect(
        SIConsoleResponseValidator.isInvalid('Trajectory updated.'),
        isFalse,
      );
      expect(SIConsoleResponseValidator.isInvalid('/help'), isFalse);
      expect(SIConsoleResponseValidator.isInvalid('0'), isFalse);
    });
  });
}
