class SIConsolePromptCopy {
  const SIConsolePromptCopy._();

  static const List<String> highImpactPrompts = <String>[
    'What is my highest-leverage next move?',
    'Show the newest task and the smartest execution order.',
    'Analyze trajectory pressure and give one corrective action.',
    'Show today\'s biggest risk and three stabilizing moves.',
    'Summarize goals drifting off course and the next correction.',
    'Compare current self to future self.',
  ];

  static String helpSection() {
    return 'High-impact strategic prompts:\n'
        '${highImpactPrompts.map((String prompt) => '- "$prompt"').join('\n')}\n\n'
        'Tip: pick a command, then ask for risk, prediction, or next move.';
  }

  static String prompt(String text) {
    return 'Prompt: "$text"';
  }
}