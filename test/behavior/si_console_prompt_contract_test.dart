import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_prompt_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI console prompt copy', () {
    test('keeps the shared help prompts and prompt wrapper stable', () {
      final String help = SIConsolePromptCopy.helpSection();

      expect(help, contains('High-impact strategic prompts:'));
      expect(help, contains('"What is my highest-leverage next move?"'));
      expect(help, contains('"Compare current self to future self."'));
      expect(SIConsolePromptCopy.highImpactPrompts, hasLength(6));
      expect(
        SIConsolePromptCopy.prompt('which one should I execute first and why?'),
        'Prompt: "which one should I execute first and why?"',
      );
    });
  });
}
