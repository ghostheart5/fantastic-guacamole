enum SIIntent { getTask, startFocus, reflect, unknown }

class SIIntentParser {
  static SIIntent parse(String input) {
    final String text = input.toLowerCase();

    if (text.contains('focus')) return SIIntent.startFocus;
    if (text.contains('what') || text.contains('task')) return SIIntent.getTask;
    if (text.contains('reflect')) return SIIntent.reflect;

    return SIIntent.unknown;
  }
}
